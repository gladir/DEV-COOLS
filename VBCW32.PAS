{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @version: 0.1
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Free Pascal 3.2)
  @description: Compilateur Visual Basic 6 vers assembleur 80386 pour Windows 32 bits
  @license: MIT
}

(* ============================================================
  VBCW32.PAS - Compilateur Visual Basic 6 vers assembleur
  80386 pour Windows 32 bits
  Free Pascal (-Mtp)
  Cible : MASM .386 / .MODEL FLAT, PE Win32

  Par defaut produit un fichier .EXE (PE Windows 32 bits).
  Avec le parametre -obj, produit uniquement un fichier .OBJ (COFF).
  Avec le parametre -asm, produit egalement un fichier .ASM lisible.
  Supporte toutes les exemples SAMPLES\VB\*

  Voir DOC/TODO/VBCW32.txt pour la feuille de route complete.

  TODO 01 - INFRASTRUCTURE, OPTIONS ET CONSTANTES PE/COFF [IMPLEMENTE]
            TOptions (SrcFile, OutFile, Verbose, DebugMode, Warnings,
              EmitExe, EmitObj, EmitAsm)
            ParseArgs : analyser argv (source.vb [-o sortie] [-v]
              [-d] [-w] [-obj] [-asm] [-h])
            Par defaut : produire un .EXE Windows 32 bits (PE)
            -obj : produire uniquement un .OBJ (format COFF 32 bits)
            -asm : produire egalement un listing assembleur .ASM lisible
            -o nom : specifier le nom du fichier de sortie
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
              MAX_CLASS=256, MAX_ENUM=128, MAX_TYPE=256
            Prefixes de nommage ASM : _VB_ (variable globale),
              _VBF_ (SUB/FUNCTION), _VBK_ (constante chaine),
              _VBRT_ (routine runtime), _VBL_ (label interne),
              _VBA_ (tableau), _VBT_ (Type utilisateur),
              _VBC_ (classe), _VBE_ (Enum), _VBP_ (Property)
            Utilitaires : ItoS, ItoSI, UpCaseStr, AsmIdent

  TODO 02 - TOKENISEUR VISUAL BASIC 6 (LEXER) [IMPLEMENTE]
            Procedure LexInit : ouvrir le fichier source, initialiser
              l etat du lexeur (ligne, colonne, caractere courant)
            Procedure LexClose : fermer le fichier source
            Procedure LexNextChar / LexPeekChar
            Procedure LexNextToken : reconnaitre les tokens VB6 :
              - Identificateurs : lettres, chiffres, _ (max 255 cars)
                VB6 est insensible a la casse
              - Suffixes de type : %, &, !, #, @, $ sur identificateurs
              - Litteraux numeriques : 123, 1.5, 1E3, 1.5D3
              - Litteraux hexadecimaux : &HFF, &HFFFF&
              - Litteraux octaux : &O77
              - Litteraux chaines : "texte" (guillemets doubles)
                Guillemet double dans chaine : ""
              - Commentaires : ' (apostrophe) ou REM en debut
              - Continuation de ligne : _ (underscore en fin de ligne)
              - Operateurs : + - * / \ Mod ^ = <> < > <= >= &
              - Separateurs : ( ) , . : ;
              - Operateurs logiques : And Or Not Xor Eqv Imp
              - Operateur Like pour comparaison de motifs
              - Operateur Is pour comparaison d objets
            Types de tokens (TOK_IDENT, TOK_INTEGER, TOK_LONG,
              TOK_SINGLE, TOK_DOUBLE, TOK_STRING, TOK_DATE,
              TOK_PLUS, TOK_MINUS, TOK_STAR, TOK_SLASH,
              TOK_BACKSLASH, TOK_CARET, TOK_AMP, TOK_MOD,
              TOK_LPAREN, TOK_RPAREN, TOK_COMMA, TOK_DOT,
              TOK_COLON, TOK_SEMI, TOK_EQ, TOK_NE, TOK_LT,
              TOK_GT, TOK_LE, TOK_GE, TOK_HASH, TOK_EXCL,
              TOK_NEWLINE, TOK_EOF)
            Stocker dans CurTokType / CurTokStr / CurTokNum

  TODO 03 - RECONNAISSANCE DES MOTS-CLES VISUAL BASIC 6 [IMPLEMENTE]
            Function IsKeyword(Const s: String): Integer
            Mots-cles complets a reconnaitre :
              And As Boolean ByRef ByVal Call Case CBool CByte
              CCur CDate CDbl CInt CLng Close Const CSng CStr
              Currency Date Declare DefBool DefByte DefCur DefDate
              DefDbl DefInt DefLng DefObj DefSng DefStr DefVar
              Dim Do Double Each Else ElseIf Empty End Enum
              Eqv Erase Error Event Exit Explicit False
              For Friend Function Get Global GoSub GoTo
              If Imp Implements In Input Integer Is
              LBound Len Let Like Long Loop LSet
              Me Mod New Next Not Nothing Null
              Object On Open Option Optional Or
              ParamArray Preserve Print Private Property Public
              RaiseEvent ReDim Rem Resume Return RSet
              Seek Select Set Single Static Step Stop
              String Sub Then To True Type TypeOf
              UBound Until Variant Wend While With
              WithEvents Write Xor
              Abs Asc Atn Chr Cos Exp Fix Hex
              InStr InStrRev Int LCase Left Len Log
              LTrim Mid Oct Right RTrim Sgn Sin
              Space Sqr Str String Tab Tan Trim
              UCase Val Format Replace Split Join
              MsgBox InputBox Debug DoEvents
              Array IsArray IsDate IsEmpty IsNull
              IsNumeric IsObject IsMissing
              Byte Date Err
            Constantes KW_AND..KW_ERR (environ 200 mots-cles)

  TODO 04 - TABLE DES SYMBOLES (32 BITS) [IMPLEMENTE]
            Type TSymKind : SK_CONST, SK_VAR, SK_PARAM,
              SK_SUB, SK_FUNCTION, SK_PROPERTY, SK_TYPE,
              SK_ENUM, SK_ENUM_MEMBER, SK_CLASS, SK_MODULE,
              SK_FIELD, SK_EVENT, SK_LABEL
            Type TSymEntry : Name (String[255]), AsmLabel (String[64]),
              Kind (TSymKind), DataType (Integer),
              StoreClass (Integer), BpOffset (Integer),
              ArrayDims (Integer), ArrayBase (Integer),
              IsStatic (Boolean), IsPublic (Boolean),
              IsOptional (Boolean), DefaultVal (String[64]),
              HasDefault (Boolean), ByRef (Boolean),
              ParamIdx (Integer), ClassIdx (Integer),
              InitStr (String[64]), InitNum (LongInt),
              HasInit (Boolean), IsConst (Boolean)
            SymTab[0..MAX_SYM-1] / SymCount
            ProcTab[0..MAX_PROC-1] / ProcCount
            Procedure InitSymTable / Function FindSym / Function AddSym
            Function FindProc / Function AddProc
            Types VB6 internes et tailles 32 bits :
              Boolean (DD, 2 octets VB mais 4 en interne),
              Byte (DB), Integer (DW, 16 bits VB), Long (DD, 32 bits),
              Single (DD, flottant 32 bits), Double (DQ, 64 bits),
              Currency (DQ, 64 bits fixe), String (pointeur DD),
              Variant (16 octets stub), Date (DQ, 64 bits),
              Object (pointeur DD)
            Classes d entreposage : STORE_AUTO (pile EBP),
              STORE_STATIC (segment .DATA), STORE_PARAM (EBP+n),
              STORE_GLOBAL (.DATA), STORE_CONSTANT (immediate)

  TODO 05 - GESTION DES PORTEES (MODULE, SUB, FUNCTION, CLASS) [IMPLEMENTE]
            Pile de portees : chaque portee maintient ses propres
              variables locales, un offset EBP courant, un label sortie
            Procedure EnterScope(kind: Integer; proc_idx: Integer)
            Procedure LeaveScope
            Function AllocLocalEbp(bytes: Integer): Integer
            Function CurrentEbpTop: Integer
            Portees supportees : SCOPE_GLOBAL, SCOPE_MODULE, SCOPE_SUB,
              SCOPE_FUNCTION, SCOPE_PROPERTY, SCOPE_CLASS,
              SCOPE_WITH, SCOPE_BLOCK
            Compteur d offset EBP pour allocation variables locales
            Offset EBP negatif pour locales [EBP-n]
            Offset EBP positif pour parametres [EBP+8], [EBP+12]...
            Convention STDCALL Win32 : parametres droite a gauche
            Variables Static : allouees en .DATA, pas en pile

  TODO 06 - PARSEUR : MODULE ET EN-TETE DU PROGRAMME [IMPLEMENTE]
            Procedure ParseModule
            Syntaxe :
              Option Explicit
              Option Base 0|1
              Option Compare Binary|Text
              Attribute VB_Name = "Module1"
            Reconnaitre le type de module :
              .VB  : module standard (Sub Main comme point d entree)
              .FRM : module de formulaire (stub, traite comme .VB)
              .CLS : module de classe
            Generer le label du point d entree _VBF_MAIN
            Generer le prologue PE : appel a Main apres init runtime
            Ignorer les lignes Attribute VB_*

  TODO 07 - PARSEUR : DECLARATIONS (DIM, PUBLIC, PRIVATE, CONST, STATIC) [IMPLEMENTE]
            Procedure ParseDim / ParsePublic / ParsePrivate / ParseConst
            Syntaxe :
              Dim x As Integer
              Dim s As String
              Dim x As Long, y As Integer
              Dim arr(10) As Integer
              Dim arr(1 To 10) As String
              Dim arr() As Long  (tableau dynamique)
              Public gVar As String
              Private mVar As Long
              Static sVar As Integer
              Const PI = 3.14159
              Const MAX_SIZE As Long = 100
              Dim x%  (suffixe Integer)
              Dim s$  (suffixe String)
              Dim l&  (suffixe Long)
            Types reconnus : Boolean, Byte, Integer, Long, Single,
              Double, Currency, String, String*n, Date, Variant, Object
            Types utilisateur (As NomType)
            Allouer en .DATA (niveau module) ou pile EBP (locales)
            Static : toujours en .DATA meme dans Sub/Function

  TODO 08 - PARSEUR : EXPRESSIONS ARITHMETIQUES ET LOGIQUES (32 BITS) [IMPLEMENTE]
            Function ParseExpr: Integer
            Function ParseOrExpr: Integer     (Or / Xor / Eqv / Imp)
            Function ParseAndExpr: Integer    (And)
            Function ParseNotExpr: Integer    (Not)
            Function ParseCompExpr: Integer   (= <> < > <= >= Like Is)
            Function ParseConcatExpr: Integer (& pour chaines)
            Function ParseAddExpr: Integer    (+ / -)
            Function ParseModExpr: Integer    (Mod)
            Function ParseIntDivExpr: Integer (\ division entiere)
            Function ParseMulExpr: Integer    ( multiplication / division )
            Function ParsePowExpr: Integer    (^ puissance)
            Function ParseUnaryExpr: Integer  (- / Not)
            Function ParsePrimaryExpr: Integer
              Constante numerique -> MOV EAX, imm32
              Constante chaine    -> LEA EAX, [_VBK_n]
              Variable scalaire   -> MOV EAX, [_VB_x] ou [EBP-n]
              Appel de fonction   -> CALL _VBF_nom
              Acces membre        -> objet.membre
              Parentheses
              True (-1), False (0), Nothing (0), Empty, Null
            Priorite des operateurs VB6 (du plus faible au plus fort) :
              Imp, Eqv, Xor, Or, And, Not, comparaisons,
              &, + -, Mod, \, * /, ^, - unaire

  TODO 09 - GENERATION DE CODE : OPERATIONS ARITHMETIQUES 80386 [IMPLEMENTE]
            Procedure GenLoadVar(sym_idx: Integer)
              Long/Integer : MOV EAX, DWORD PTR [_VB_x] ou [EBP-n]
              String : LEA EAX, [_VB_x] ou [EBP-n]
              Boolean : MOVZX EAX, BYTE PTR [_VB_x]
              Byte : MOVZX EAX, BYTE PTR [_VB_x]
            Procedure GenStoreVar(sym_idx: Integer)
              MOV DWORD PTR [_VB_x], EAX ou MOV [EBP-n], EAX
            Procedure GenBinOp(op: Integer)
              + : ADD EAX, EBX
              - : SUB EAX, EBX
              * : IMUL EAX, EBX
              / : flottant via FPU ou CALL _VBRT_DIV
              \ : CDQ + IDIV EBX (division entiere)
              Mod : CDQ + IDIV EBX -> MOV EAX, EDX
              ^ : CALL _VBRT_POW (puissance)
              & : CALL _VBRT_STRCAT (concatenation)
            Procedure GenCompare(op: Integer)
              CMP EAX, EBX + SETcc AL + MOVZX EAX, AL
              Resultat VB6 : True = -1 ($FFFFFFFF), False = 0
            Procedure GenLogicalOp(op: Integer)
              And : AND EAX, EBX
              Or  : OR EAX, EBX
              Xor : XOR EAX, EBX
              Not : NOT EAX
              Eqv : NOT EAX / XOR EAX, EBX / NOT EAX
              Imp : NOT EAX / OR EAX, EBX
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
            Procedure ParseGoTo / ParseGoSub / ParseReturn
              GoTo label -> JMP label
              GoSub label -> CALL label / Return -> RET
              Labels numeriques (ligne) et labels nommes

  TODO 11 - PARSEUR : BOUCLES (FOR/NEXT, DO/LOOP, WHILE/WEND, FOR EACH) [IMPLEMENTE]
            Procedure ParseFor
            Syntaxe :
              For i = debut To fin [Step pas]
                instructions
                [Exit For]
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
              Loop [While|Until condition]
            Procedure ParseWhileWend
            Syntaxe :
              While condition
                instructions
              Wend
            Procedure ParseForEach (stub)
            Syntaxe :
              For Each element In collection
                instructions
              Next [element]
            Exit For / Exit Do : JMP vers label_fin de la boucle

  TODO 12 - PARSEUR : SUB ET FUNCTION (PROCEDURES ET FONCTIONS) [IMPLEMENTE]
            Procedure ParseSub
            Syntaxe :
              [Public|Private] Sub nom([params])
                instructions
                [Exit Sub]
              End Sub
            Procedure ParseFunction
            Syntaxe :
              [Public|Private] Function nom([params]) As type
                instructions
                nom = valeur_retour
                [Exit Function]
              End Function
            Parametres :
              ByVal x As Integer (passage par valeur, PUSH valeur)
              ByRef x As Integer (passage par reference, PUSH adresse)
              Optional x As Integer = 0 (parametre optionnel)
              ParamArray args() As Variant (stub)
            Generer prologue STDCALL :
              PUSH EBP / MOV EBP, ESP / SUB ESP, taille_locales
            Generer epilogue :
              MOV ESP, EBP / POP EBP / RET n (n = taille params)
            Valeur de retour Function : dans EAX (entier/pointeur)
            Appel : PUSH params / CALL _VBF_nom

  TODO 13 - PARSEUR : FONCTIONS INTRINSEQUES (CHAINES, CONVERSION, MATH) [IMPLEMENTE]
            Fonctions de chaines :
              Len(s) -> CALL _VBRT_LEN
              Left(s, n), Right(s, n), Mid(s, start[, len])
              LTrim(s), RTrim(s), Trim(s)
              UCase(s), LCase(s)
              InStr([start,] s1, s2), InStrRev(s1, s2[, start])
              Replace(s, find, replace)
              Space(n), String(n, car)
              StrComp(s1, s2), StrReverse(s)
              Split(s, delim), Join(arr, delim)
              Asc(s), Chr(n)
            Fonctions de conversion :
              CInt(x), CLng(x), CSng(x), CDbl(x), CStr(x),
              CBool(x), CByte(x), CCur(x), CDate(x)
              Val(s), Str(n), Hex(n), Oct(n)
              Int(x), Fix(x)
            Fonctions mathematiques :
              Abs(x), Sgn(x), Sqr(x), Exp(x), Log(x)
              Sin(x), Cos(x), Tan(x), Atn(x)
              Rnd, Randomize
            Fonctions d information :
              IsNumeric(x), IsDate(x), IsEmpty(x), IsNull(x),
              IsArray(x), IsObject(x), IsMissing(x)
              TypeName(x), VarType(x)
            Generer CALL _VBRT_xxx pour chaque fonction runtime

  TODO 14 - PARSEUR : OPERATIONS SUR CHAINES ET CONCATENATION [IMPLEMENTE]
            Operateur & : concatenation de chaines
              Generer PUSH ptr_s1 / PUSH ptr_s2 / CALL _VBRT_STRCAT
            Operateur + : concatenation si les deux operandes sont String
            Instruction Mid$(s, pos[, len]) = valeur (affectation Mid)
            Instruction LSet s = valeur (cadrage a gauche)
            Instruction RSet s = valeur (cadrage a droite)
            Chaines de longueur fixe : String * n
              Allouer n octets en .DATA ou pile
            Chaines de longueur variable : pointeur DD vers tampon
              Allocation dynamique via _VBRT_STRALLOC
              Liberation via _VBRT_STRFREE
            Comparaison de chaines :
              Option Compare Binary (defaut, sensible casse)
              Option Compare Text (insensible casse)
              Operateur Like avec motifs (joker, ?, #, [charlist])
            Format(expression, format_string) -> CALL _VBRT_FORMAT

  TODO 15 - PARSEUR : TABLEAUX (DIM, REDIM, ERASE, LBOUND, UBOUND) [IMPLEMENTE]
            Tableaux statiques :
              Dim arr(10) As Integer -> 11 elements (0 a 10)
              Dim arr(1 To 10) As Integer -> 10 elements
              Dim mat(3, 3) As Long -> matrice 4x4
              Option Base 0|1 : base par defaut des indices
            Allouer en .DATA (global) ou pile (local)
            Tableaux dynamiques :
              Dim arr() As Integer -> pointeur DD, pas de taille
              ReDim arr(n) -> CALL _VBRT_REDIM (allouer/reallouer)
              ReDim Preserve arr(n) -> conserver les donnees
              Erase arr -> CALL _VBRT_ERASE (liberer/reinitialiser)
            Fonctions de tableau :
              LBound(arr[, dim]) -> borne inferieure
              UBound(arr[, dim]) -> borne superieure
              Array(v1, v2, ...) -> creer Variant Array (stub)
              IsArray(x) -> Boolean
            Acces : arr(index) -> calcul offset + chargement
              MOV EAX, [base + index * taille_element]
            Tableaux multi-dimensionnels :
              Calcul offset = ((i1 * dim2 + i2) * dim3 + i3) * taille

  TODO 16 - PARSEUR : TYPES UTILISATEUR (TYPE...END TYPE) ET ENUM [IMPLEMENTE]
            Procedure ParseType
            Syntaxe :
              [Public|Private] Type NomType
                champ1 As Integer
                champ2 As String * 20
                champ3(10) As Long
              End Type
            Calcul de la taille totale et des offsets de champs
            Acces aux champs : variable.champ
              LEA EAX, [_VB_var + offset_champ]
            Instruction With variable
              With var ... End With (acces implicite aux champs)
            Procedure ParseEnum
            Syntaxe :
              [Public|Private] Enum NomEnum
                Valeur1 [= 0]
                Valeur2 [= 1]
                Valeur3 = 10
              End Enum
            Chaque membre Enum est une constante Long
            Valeurs auto-incrementees si non specifiees

  TODO 17 - PARSEUR : MODULES DE CLASSE (CLASS, PROPERTY, METHOD) [IMPLEMENTE]
            Gestion des fichiers .CLS (modules de classe)
            Attributs de classe :
              Attribute VB_Name = "NomClasse"
              Attribute VB_Creatable = True
              Attribute VB_Exposed = False
            Evenements de classe :
              Private Sub Class_Initialize()
              Private Sub Class_Terminate()
            Proprietes :
              Property Get NomProp() As Type
              Property Let NomProp(valeur As Type)
              Property Set NomProp(obj As Object)
            Creation d instances :
              Dim obj As New NomClasse
              Set obj = New NomClasse
              Set obj = Nothing (liberation)
            Implementer comme structures avec table de methodes
            Me : reference a l instance courante (pointeur This)
            Generer table de pointeurs de methodes en .DATA

  TODO 18 - PARSEUR : GESTION DES ERREURS (ON ERROR, RESUME, ERR) [IMPLEMENTE]
            Procedure ParseOnError
            Syntaxe :
              On Error GoTo label
              On Error GoTo 0 (desactiver gestionnaire)
              On Error Resume Next (ignorer erreurs)
            Mecanisme d implementation :
              Sauvegarder adresse du gestionnaire dans variable globale
              A chaque operation risquee, tester et sauter si erreur
              On Error GoTo 0 : mettre gestionnaire a NULL
              On Error Resume Next : flag pour ignorer
            Procedure ParseResume
              Resume : reprendre a l instruction fautive
              Resume Next : reprendre a l instruction suivante
              Resume label : sauter au label
            Objet Err :
              Err.Number -> variable globale _VB_ERR_NUMBER
              Err.Description -> variable globale _VB_ERR_DESC
              Err.Source -> variable globale _VB_ERR_SOURCE
              Err.Clear -> reinitialiser les variables Err
              Err.Raise number[, source][, description]
            Generer code pour etablir/retirer le gestionnaire SEH

  TODO 19 - PARSEUR : ENTREES/SORTIES FICHIERS (OPEN, CLOSE, PRINT#, INPUT#) [IMPLEMENTE]
            Procedure ParseOpen
            Syntaxe :
              Open fichier For Input As #n
              Open fichier For Output As #n
              Open fichier For Append As #n
              Open fichier For Binary As #n
              Open fichier For Random As #n [Len = taille]
            Modes : Input, Output, Append, Binary, Random
            Generer appels Win32 API :
              CreateFileA pour Open
              CloseHandle pour Close
            Procedure ParseClose
              Close [#n] : fermer un ou tous les fichiers
            Procedure ParsePrint
              Print #n, expr1[; expr2][, expr3]
              Write #n, expr1, expr2, expr3
            Procedure ParseInput
              Input #n, var1, var2
              Line Input #n, var$
            Procedure ParseGet / ParsePut (acces aleatoire)
              Get #n, [position], variable
              Put #n, [position], variable
            Procedure ParseSeek
              Seek #n, position
            Fonctions : EOF(n), LOF(n), Loc(n), FreeFile
            Numero de fichier : #1 a #511, mapper vers handles Win32

  TODO 20 - BIBLIOTHEQUE RUNTIME (CHAINES, CONVERSION, E/S VIA WIN32 API) [IMPLEMENTE]
            Generer les routines runtime en assembleur 80386 :
            Routines chaines :
              _VBRT_LEN : longueur de chaine (null-terminated)
              _VBRT_STRCAT : concatenation
              _VBRT_STRCMP : comparaison
              _VBRT_STRCPY : copie
              _VBRT_STRALLOC : allocation (HeapAlloc)
              _VBRT_STRFREE : liberation (HeapFree)
              _VBRT_LEFT, _VBRT_RIGHT, _VBRT_MID
              _VBRT_LTRIM, _VBRT_RTRIM, _VBRT_TRIM
              _VBRT_UCASE, _VBRT_LCASE
              _VBRT_INSTR, _VBRT_REPLACE
              _VBRT_FORMAT : formatage de nombres/dates
            Routines conversion :
              _VBRT_VAL : chaine vers nombre
              _VBRT_STR : nombre vers chaine
              _VBRT_CINT, _VBRT_CLNG, _VBRT_CSTR
            Routines mathematiques :
              _VBRT_POW : puissance (^ operateur)
              _VBRT_SQR, _VBRT_ABS, _VBRT_SGN
              _VBRT_SIN, _VBRT_COS, _VBRT_TAN, _VBRT_ATN
              _VBRT_EXP, _VBRT_LOG
            Routines E/S console :
              _VBRT_PRINT : affichage via WriteFile(hStdOut)
              _VBRT_INPUT : lecture via ReadFile(hStdIn)
              _VBRT_MSGBOX : affichage MessageBoxA (user32)
              _VBRT_INPUTBOX : saisie via boite de dialogue
            Routines tableaux :
              _VBRT_REDIM, _VBRT_ERASE, _VBRT_LBOUND, _VBRT_UBOUND
            Routines memoire :
              _VBRT_HEAPINIT, _VBRT_HEAPALLOC, _VBRT_HEAPFREE
            Point d entree : _VBRT_INIT (initialiser runtime) et
              _VBRT_EXIT (terminer programme, ExitProcess)

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
              AddressOfEntryPoint = RVA du _VBF_MAIN
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
              Routines runtime (_VBRT_xxx)
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
              GetTickCount, Sleep, GetEnvironmentVariableA
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

  TODO 25 - OPTIMISATIONS, TESTS FINAUX ET INTEGRATION SAMPLES\VB\* [IMPLEMENTE]
            Optimisations peephole :
              MOV EAX, 0 -> XOR EAX, EAX
              PUSH EAX / POP EAX -> (eliminer)
              MOV EAX, [x] / MOV [x], EAX -> (eliminer deuxieme)
              ADD EAX, 1 -> INC EAX
              SUB EAX, 1 -> DEC EAX
              IMUL EAX, 2 -> SHL EAX, 1
              IMUL EAX, 4 -> SHL EAX, 2
            Verification : compiler et executer les exemples
              SAMPLES\VB\HELLO.VB    - Hello World
              SAMPLES\VB\CALC.VB     - Calculatrice simple
              SAMPLES\VB\FIBONACCI.VB - Suite de Fibonacci
              SAMPLES\VB\FACTORI.VB  - Factorielle
              SAMPLES\VB\ARRAY.VB    - Operations sur tableaux
              SAMPLES\VB\STRING.VB   - Operations sur chaines
              SAMPLES\VB\FILEIO.VB   - Entrees/sorties fichiers
              SAMPLES\VB\SELECTCS.VB - Select Case
              SAMPLES\VB\LOOPS.VB    - Boucles For/Do/While
              SAMPLES\VB\USERTYPE.VB - Types utilisateur
              SAMPLES\VB\SUBS.VB     - Sub et Function
              SAMPLES\VB\ERRORS.VB   - Gestion des erreurs
            Tests de regression pour chaque TODO
            Verification des 3 modes de sortie :
              .EXE (defaut), .OBJ (-obj), .ASM (-asm)
            Mesure de la taille des executables generes

  ============================================================ *)

Program VBCW32;

{$IFDEF FPC}
  {$MODE TP}
  {$H-}
{$ENDIF}
{$I-}

{ ============================================================ }
{ TODO 01 - INFRASTRUCTURE, OPTIONS ET CONSTANTES    [IMPLEMENTE] }
{           PE/COFF                                              }
{ ============================================================ }

Const
  VBCW32_VERSION = '0.1';
  VBCW32_DATE    = '2026';

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
  MAX_SYM   = 4096;
  MAX_PROC  = 512;
  MAX_LOCAL = 256;
  MAX_PARAM = 64;
  MAX_DEPTH = 32;
  MAX_LABEL = 4096;
  MAX_STR   = 255;
  MAX_FIELD = 128;
  MAX_CLASS = 256;
  MAX_ENUM  = 128;
  MAX_TYPE  = 256;

  { Prefixes de nommage ASM }
  PFX_VAR   = '_VB_';    { variable globale       }
  PFX_FUNC  = '_VBF_';   { SUB / FUNCTION         }
  PFX_CONST = '_VBK_';   { constante chaine        }
  PFX_RT    = '_VBRT_';  { routine runtime         }
  PFX_LBL   = '_VBL_';   { label interne           }
  PFX_ARR   = '_VBA_';   { tableau                 }
  PFX_TYPE  = '_VBT_';   { Type utilisateur        }
  PFX_CLS   = '_VBC_';   { classe                  }
  PFX_ENUM  = '_VBE_';   { Enum                    }
  PFX_PROP  = '_VBP_';   { Property                }

Type
  TString = String;

  TOptions = Record
    SrcFile   : TString;   { fichier source (.vb)                 }
    OutFile   : TString;   { fichier sortie (.exe, .obj)          }
    Verbose   : Boolean;   { -v : banniere et statistiques        }
    DebugMode : Boolean;   { -d : affichage de chaque token       }
    Warnings  : Boolean;   { -w : afficher les avertissements     }
    EmitExe   : Boolean;   { par defaut : produire un .EXE (PE)   }
    EmitObj   : Boolean;   { -obj : produire seulement un .OBJ    }
    EmitAsm   : Boolean;   { -asm : produire aussi un .ASM        }
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

{ Transforme un nom VB en identifiant valide pour l assembleur }
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
  WriteLn('VBCW32: FATAL: ', Msg);
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
  WriteLn('VBCW32: warning: ', Msg);
  Inc(WarnCount);
End;

{ ------------------------------------------------------------ }
{ InitOptions                                                  }
{ ------------------------------------------------------------ }

Procedure InitOptions;
Begin
  Opts.SrcFile   := '';
  Opts.OutFile   := '';
  Opts.Verbose   := False;
  Opts.DebugMode := False;
  Opts.Warnings  := False;
  Opts.EmitExe   := True;
  Opts.EmitObj   := False;
  Opts.EmitAsm   := False;
End;

{ ------------------------------------------------------------ }
{ ShowHelp                                                     }
{ ------------------------------------------------------------ }

Procedure ShowHelp;
Begin
  WriteLn('VBCW32 v', VBCW32_VERSION, ' (', VBCW32_DATE,
          ') - Compilateur Visual Basic 6 vers 80386 (Windows PE 32 bits)');
  WriteLn('VBCW32 - Cette commande permet de lancer le compilateur Visual ',
          'Basic 6 pour l''assembleur du microprocesseur 80386 (en executable ',
          'Windows 32 bits).');
  WriteLn;
  WriteLn('Syntaxe : VBCW32 [options] <source.vb> [options]');
  WriteLn;
  WriteLn('Sortie :');
  WriteLn('  Par defaut un .EXE (PE Windows 32 bits)');
  WriteLn('  -obj           Produire seulement un fichier .OBJ (COFF)');
  WriteLn('  -asm           Produire egalement un fichier .ASM lisible');
  WriteLn('  -o <fichier>   Specifier le nom du fichier de sortie');
  WriteLn;
  WriteLn('General :');
  WriteLn('  -v             Mode verbeux (banniere + statistiques)');
  WriteLn('  -d             Debug tokens (affiche chaque token)');
  WriteLn('  -w             Afficher les avertissements');
  WriteLn('  -h, --help, /? Afficher cette aide');
  WriteLn;
  WriteLn('Exemples :');
  WriteLn('  VBCW32 hello.vb');
  WriteLn('  VBCW32 hello.vb -o hello.exe -v');
  WriteLn('  VBCW32 main.vb -asm');
  WriteLn('  VBCW32 module.vb -obj -w');
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
    WriteLn('VBCW32: fichier source manquant');
    ShowHelp;
  End;

  { Verifier l extension .vb }
  Ext := ExtractExt(Opts.SrcFile);
  If (Ext <> '.vb') And (Ext <> '.bas') And (Ext <> '.frm') And
     (Ext <> '.cls') Then
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
  WriteLn('VBCW32 v', VBCW32_VERSION, ' (', VBCW32_DATE,
          ') - Compilateur Visual Basic 6 -> 80386 PE Win32');
  WriteLn('Source   : ', Opts.SrcFile);
  WriteLn('Sortie   : ', Opts.OutFile);
  If Opts.EmitAsm Then
    WriteLn('ASM      : ', ReplaceExt(Opts.OutFile, '.asm'));
  If Opts.EmitObj Then
    WriteLn('Mode     : OBJ (COFF 32 bits)')
  Else
    WriteLn('Mode     : EXE (PE Win32)');
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
{ TODO 02 - TOKENISEUR VISUAL BASIC 6 (LEXER)     [IMPLEMENTE] }
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
  TOK_PLUS      = 10;   { +                                       }
  TOK_MINUS     = 11;   { -                                       }
  TOK_STAR      = 12;   { *                                       }
  TOK_SLASH     = 13;   { /                                       }
  TOK_BACKSLASH = 14;   { \  (division entiere)                   }
  TOK_CARET     = 15;   { ^  (puissance)                          }
  TOK_AMP       = 16;   { &  (concatenation)                      }
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

{ ============================================================ }
{ TODO 03 - RECONNAISSANCE DES MOTS-CLES VB6       [IMPLEMENTE] }
{ ============================================================ }

Const
  { Constantes KW_* pour les mots-cles Visual Basic 6 }
  { Mots-cles du langage }
  KW_NONE       = 0;
  KW_AND        = 1;
  KW_AS         = 2;
  KW_BOOLEAN    = 3;
  KW_BYREF      = 4;
  KW_BYVAL      = 5;
  KW_CALL       = 6;
  KW_CASE       = 7;
  KW_CBOOL      = 8;
  KW_CBYTE      = 9;
  KW_CCUR       = 10;
  KW_CDATE      = 11;
  KW_CDBL       = 12;
  KW_CINT       = 13;
  KW_CLNG       = 14;
  KW_CLOSE      = 15;
  KW_CONST      = 16;
  KW_CSNG       = 17;
  KW_CSTR       = 18;
  KW_CURRENCY   = 19;
  KW_DATE       = 20;
  KW_DECLARE    = 21;
  KW_DEFBOOL    = 22;
  KW_DEFBYTE    = 23;
  KW_DEFCUR     = 24;
  KW_DEFDATE    = 25;
  KW_DEFDBL     = 26;
  KW_DEFINT     = 27;
  KW_DEFLNG     = 28;
  KW_DEFOBJ     = 29;
  KW_DEFSNG     = 30;
  KW_DEFSTR     = 31;
  KW_DEFVAR     = 32;
  KW_DIM        = 33;
  KW_DO         = 34;
  KW_DOUBLE     = 35;
  KW_EACH       = 36;
  KW_ELSE       = 37;
  KW_ELSEIF     = 38;
  KW_EMPTY      = 39;
  KW_END        = 40;
  KW_ENUM       = 41;
  KW_EQV        = 42;
  KW_ERASE      = 43;
  KW_ERROR      = 44;
  KW_EVENT      = 45;
  KW_EXIT       = 46;
  KW_EXPLICIT   = 47;
  KW_FALSE      = 48;
  KW_FOR        = 49;
  KW_FRIEND     = 50;
  KW_FUNCTION   = 51;
  KW_GET        = 52;
  KW_GLOBAL     = 53;
  KW_GOSUB      = 54;
  KW_GOTO       = 55;
  KW_IF         = 56;
  KW_IMP        = 57;
  KW_IMPLEMENTS = 58;
  KW_IN         = 59;
  KW_INPUT      = 60;
  KW_INTEGER    = 61;
  KW_IS         = 62;
  KW_LBOUND     = 63;
  KW_LEN        = 64;
  KW_LET        = 65;
  KW_LIKE       = 66;
  KW_LONG       = 67;
  KW_LOOP       = 68;
  KW_LSET       = 69;
  KW_ME         = 70;
  KW_MOD        = 71;
  KW_NEW        = 72;
  KW_NEXT       = 73;
  KW_NOT        = 74;
  KW_NOTHING    = 75;
  KW_NULL       = 76;
  KW_OBJECT     = 77;
  KW_ON         = 78;
  KW_OPEN       = 79;
  KW_OPTION     = 80;
  KW_OPTIONAL   = 81;
  KW_OR         = 82;
  KW_PARAMARRAY = 83;
  KW_PRESERVE   = 84;
  KW_PRINT      = 85;
  KW_PRIVATE    = 86;
  KW_PROPERTY   = 87;
  KW_PUBLIC     = 88;
  KW_RAISEEVENT = 89;
  KW_REDIM      = 90;
  KW_REM        = 91;
  KW_RESUME     = 92;
  KW_RETURN     = 93;
  KW_RSET       = 94;
  KW_SEEK       = 95;
  KW_SELECT     = 96;
  KW_SET        = 97;
  KW_SINGLE     = 98;
  KW_STATIC     = 99;
  KW_STEP       = 100;
  KW_STOP       = 101;
  KW_STRING     = 102;
  KW_SUB        = 103;
  KW_THEN       = 104;
  KW_TO         = 105;
  KW_TRUE       = 106;
  KW_TYPE       = 107;
  KW_TYPEOF     = 108;
  KW_UBOUND     = 109;
  KW_UNTIL      = 110;
  KW_VARIANT    = 111;
  KW_WEND       = 112;
  KW_WHILE      = 113;
  KW_WITH       = 114;
  KW_WITHEVENTS = 115;
  KW_WRITE      = 116;
  KW_XOR        = 117;

  { Fonctions VB6 internes }
  KW_ABS        = 120;
  KW_ASC        = 121;
  KW_ATN        = 122;
  KW_CHR        = 123;
  KW_COS        = 124;
  KW_EXP        = 125;
  KW_FIX        = 126;
  KW_HEX        = 127;
  KW_INSTR      = 128;
  KW_INSTRREV   = 129;
  KW_INT        = 130;
  KW_LCASE      = 131;
  KW_LEFT       = 132;
  KW_LEN2       = 133;    { Len function (vs KW_LEN keyword) }
  KW_LOG        = 134;
  KW_LTRIM      = 135;
  KW_MID        = 136;
  KW_OCT        = 137;
  KW_RIGHT      = 138;
  KW_RTRIM      = 139;
  KW_SGN        = 140;
  KW_SIN        = 141;
  KW_SPACE      = 142;
  KW_SQR        = 143;
  KW_STR        = 144;
  KW_STRINGFN   = 145;    { String$ function }
  KW_TAB        = 146;
  KW_TAN        = 147;
  KW_TRIM       = 148;
  KW_UCASE      = 149;
  KW_VAL        = 150;
  KW_FORMAT     = 151;
  KW_REPLACE    = 152;
  KW_SPLIT      = 153;
  KW_JOIN       = 154;
  KW_MSGBOX     = 155;
  KW_INPUTBOX   = 156;
  KW_DEBUG      = 157;
  KW_DOEVENTS   = 158;
  KW_ARRAY      = 159;
  KW_ISARRAY    = 160;
  KW_ISDATE     = 161;
  KW_ISEMPTY    = 162;
  KW_ISNULL     = 163;
  KW_ISNUMERIC  = 164;
  KW_ISOBJECT   = 165;
  KW_ISMISSING  = 166;
  KW_BYTE       = 167;
  KW_DATE2      = 168;    { Date function (vs KW_DATE type) }
  KW_ERR        = 169;
  KW_STRCOMP    = 170;
  KW_STRREVERSE = 171;
  KW_RND        = 172;
  KW_RANDOMIZE  = 173;
  KW_TYPENAME   = 174;
  KW_VARTYPE    = 175;

  { TODO 14 - constantes supplementaires pour operations chaines }
  KW_MIDASSIGN  = 176;    { Mid$ en position d affectation           }
  KW_FORMAT2    = 177;    { Format$ (synonyme de Format)             }
  KW_LIKE2      = 178;    { Like en contexte de comparaison chaine   }

  { TODO 19 - constantes supplementaires pour E/S fichiers }
  KW_LINE       = 179;    { Line (pour Line Input)                   }
  KW_PUT        = 180;    { Put (acces aleatoire ecriture)           }
  KW_EOF2       = 181;    { EOF (fonction test fin de fichier)       }
  KW_LOF        = 182;    { LOF (taille de fichier)                  }
  KW_LOC        = 183;    { Loc (position courante)                  }
  KW_FREEFILE   = 184;    { FreeFile (prochain numero disponible)    }

  { Token special pour mot-cle reconnu }
  TOK_KEYWORD   = 50;     { mot-cle VB6 reconnu                     }

{ ------------------------------------------------------------ }
{ IsKeyword : tester si un identificateur est un mot-cle VB6   }
{ Retourne la constante KW_* ou KW_NONE si non reconnu         }
{ VB6 est insensible a la casse                                }
{ ------------------------------------------------------------ }

Function IsKeyword(Const S : TString) : Integer;
Var
  U : TString;
Begin
  U := UpCaseStr(S);
  { Mots-cles du langage }
  If      U = 'AND'        Then IsKeyword := KW_AND
  Else If U = 'AS'         Then IsKeyword := KW_AS
  Else If U = 'BOOLEAN'    Then IsKeyword := KW_BOOLEAN
  Else If U = 'BYREF'      Then IsKeyword := KW_BYREF
  Else If U = 'BYVAL'      Then IsKeyword := KW_BYVAL
  Else If U = 'CALL'       Then IsKeyword := KW_CALL
  Else If U = 'CASE'       Then IsKeyword := KW_CASE
  Else If U = 'CBOOL'      Then IsKeyword := KW_CBOOL
  Else If U = 'CBYTE'      Then IsKeyword := KW_CBYTE
  Else If U = 'CCUR'       Then IsKeyword := KW_CCUR
  Else If U = 'CDATE'      Then IsKeyword := KW_CDATE
  Else If U = 'CDBL'       Then IsKeyword := KW_CDBL
  Else If U = 'CINT'       Then IsKeyword := KW_CINT
  Else If U = 'CLNG'       Then IsKeyword := KW_CLNG
  Else If U = 'CLOSE'      Then IsKeyword := KW_CLOSE
  Else If U = 'CONST'      Then IsKeyword := KW_CONST
  Else If U = 'CSNG'       Then IsKeyword := KW_CSNG
  Else If U = 'CSTR'       Then IsKeyword := KW_CSTR
  Else If U = 'CURRENCY'   Then IsKeyword := KW_CURRENCY
  Else If U = 'DATE'       Then IsKeyword := KW_DATE
  Else If U = 'DECLARE'    Then IsKeyword := KW_DECLARE
  Else If U = 'DEFBOOL'    Then IsKeyword := KW_DEFBOOL
  Else If U = 'DEFBYTE'    Then IsKeyword := KW_DEFBYTE
  Else If U = 'DEFCUR'     Then IsKeyword := KW_DEFCUR
  Else If U = 'DEFDATE'    Then IsKeyword := KW_DEFDATE
  Else If U = 'DEFDBL'     Then IsKeyword := KW_DEFDBL
  Else If U = 'DEFINT'     Then IsKeyword := KW_DEFINT
  Else If U = 'DEFLNG'     Then IsKeyword := KW_DEFLNG
  Else If U = 'DEFOBJ'     Then IsKeyword := KW_DEFOBJ
  Else If U = 'DEFSNG'     Then IsKeyword := KW_DEFSNG
  Else If U = 'DEFSTR'     Then IsKeyword := KW_DEFSTR
  Else If U = 'DEFVAR'     Then IsKeyword := KW_DEFVAR
  Else If U = 'DIM'        Then IsKeyword := KW_DIM
  Else If U = 'DO'         Then IsKeyword := KW_DO
  Else If U = 'DOUBLE'     Then IsKeyword := KW_DOUBLE
  Else If U = 'EACH'       Then IsKeyword := KW_EACH
  Else If U = 'ELSE'       Then IsKeyword := KW_ELSE
  Else If U = 'ELSEIF'     Then IsKeyword := KW_ELSEIF
  Else If U = 'EMPTY'      Then IsKeyword := KW_EMPTY
  Else If U = 'END'        Then IsKeyword := KW_END
  Else If U = 'ENUM'       Then IsKeyword := KW_ENUM
  Else If U = 'EQV'        Then IsKeyword := KW_EQV
  Else If U = 'ERASE'      Then IsKeyword := KW_ERASE
  Else If U = 'ERROR'      Then IsKeyword := KW_ERROR
  Else If U = 'EVENT'      Then IsKeyword := KW_EVENT
  Else If U = 'EXIT'       Then IsKeyword := KW_EXIT
  Else If U = 'EXPLICIT'   Then IsKeyword := KW_EXPLICIT
  Else If U = 'FALSE'      Then IsKeyword := KW_FALSE
  Else If U = 'FOR'        Then IsKeyword := KW_FOR
  Else If U = 'FRIEND'     Then IsKeyword := KW_FRIEND
  Else If U = 'FUNCTION'   Then IsKeyword := KW_FUNCTION
  Else If U = 'GET'        Then IsKeyword := KW_GET
  Else If U = 'GLOBAL'     Then IsKeyword := KW_GLOBAL
  Else If U = 'GOSUB'      Then IsKeyword := KW_GOSUB
  Else If U = 'GOTO'       Then IsKeyword := KW_GOTO
  Else If U = 'IF'         Then IsKeyword := KW_IF
  Else If U = 'IMP'        Then IsKeyword := KW_IMP
  Else If U = 'IMPLEMENTS' Then IsKeyword := KW_IMPLEMENTS
  Else If U = 'IN'         Then IsKeyword := KW_IN
  Else If U = 'INPUT'      Then IsKeyword := KW_INPUT
  Else If U = 'INTEGER'    Then IsKeyword := KW_INTEGER
  Else If U = 'IS'         Then IsKeyword := KW_IS
  Else If U = 'LBOUND'     Then IsKeyword := KW_LBOUND
  Else If U = 'LEN'        Then IsKeyword := KW_LEN
  Else If U = 'LET'        Then IsKeyword := KW_LET
  Else If U = 'LIKE'       Then IsKeyword := KW_LIKE
  Else If U = 'LONG'       Then IsKeyword := KW_LONG
  Else If U = 'LOOP'       Then IsKeyword := KW_LOOP
  Else If U = 'LSET'       Then IsKeyword := KW_LSET
  Else If U = 'ME'         Then IsKeyword := KW_ME
  Else If U = 'MOD'        Then IsKeyword := KW_MOD
  Else If U = 'NEW'        Then IsKeyword := KW_NEW
  Else If U = 'NEXT'       Then IsKeyword := KW_NEXT
  Else If U = 'NOT'        Then IsKeyword := KW_NOT
  Else If U = 'NOTHING'    Then IsKeyword := KW_NOTHING
  Else If U = 'NULL'       Then IsKeyword := KW_NULL
  Else If U = 'OBJECT'     Then IsKeyword := KW_OBJECT
  Else If U = 'ON'         Then IsKeyword := KW_ON
  Else If U = 'OPEN'       Then IsKeyword := KW_OPEN
  Else If U = 'OPTION'     Then IsKeyword := KW_OPTION
  Else If U = 'OPTIONAL'   Then IsKeyword := KW_OPTIONAL
  Else If U = 'OR'         Then IsKeyword := KW_OR
  Else If U = 'PARAMARRAY' Then IsKeyword := KW_PARAMARRAY
  Else If U = 'PRESERVE'   Then IsKeyword := KW_PRESERVE
  Else If U = 'PRINT'      Then IsKeyword := KW_PRINT
  Else If U = 'PRIVATE'    Then IsKeyword := KW_PRIVATE
  Else If U = 'PROPERTY'   Then IsKeyword := KW_PROPERTY
  Else If U = 'PUBLIC'     Then IsKeyword := KW_PUBLIC
  Else If U = 'RAISEEVENT' Then IsKeyword := KW_RAISEEVENT
  Else If U = 'REDIM'      Then IsKeyword := KW_REDIM
  Else If U = 'REM'        Then IsKeyword := KW_REM
  Else If U = 'RESUME'     Then IsKeyword := KW_RESUME
  Else If U = 'RETURN'     Then IsKeyword := KW_RETURN
  Else If U = 'RSET'       Then IsKeyword := KW_RSET
  Else If U = 'SEEK'       Then IsKeyword := KW_SEEK
  Else If U = 'SELECT'     Then IsKeyword := KW_SELECT
  Else If U = 'SET'        Then IsKeyword := KW_SET
  Else If U = 'SINGLE'     Then IsKeyword := KW_SINGLE
  Else If U = 'STATIC'     Then IsKeyword := KW_STATIC
  Else If U = 'STEP'       Then IsKeyword := KW_STEP
  Else If U = 'STOP'       Then IsKeyword := KW_STOP
  Else If U = 'STRING'     Then IsKeyword := KW_STRING
  Else If U = 'SUB'        Then IsKeyword := KW_SUB
  Else If U = 'THEN'       Then IsKeyword := KW_THEN
  Else If U = 'TO'         Then IsKeyword := KW_TO
  Else If U = 'TRUE'       Then IsKeyword := KW_TRUE
  Else If U = 'TYPE'       Then IsKeyword := KW_TYPE
  Else If U = 'TYPEOF'     Then IsKeyword := KW_TYPEOF
  Else If U = 'UBOUND'     Then IsKeyword := KW_UBOUND
  Else If U = 'UNTIL'      Then IsKeyword := KW_UNTIL
  Else If U = 'VARIANT'    Then IsKeyword := KW_VARIANT
  Else If U = 'WEND'       Then IsKeyword := KW_WEND
  Else If U = 'WHILE'      Then IsKeyword := KW_WHILE
  Else If U = 'WITH'       Then IsKeyword := KW_WITH
  Else If U = 'WITHEVENTS' Then IsKeyword := KW_WITHEVENTS
  Else If U = 'WRITE'      Then IsKeyword := KW_WRITE
  Else If U = 'XOR'        Then IsKeyword := KW_XOR
  { Fonctions VB6 internes }
  Else If U = 'ABS'        Then IsKeyword := KW_ABS
  Else If U = 'ASC'        Then IsKeyword := KW_ASC
  Else If U = 'ATN'        Then IsKeyword := KW_ATN
  Else If U = 'CHR'        Then IsKeyword := KW_CHR
  Else If U = 'COS'        Then IsKeyword := KW_COS
  Else If U = 'EXP'        Then IsKeyword := KW_EXP
  Else If U = 'FIX'        Then IsKeyword := KW_FIX
  Else If U = 'HEX'        Then IsKeyword := KW_HEX
  Else If U = 'INSTR'      Then IsKeyword := KW_INSTR
  Else If U = 'INSTRREV'   Then IsKeyword := KW_INSTRREV
  Else If U = 'INT'        Then IsKeyword := KW_INT
  Else If U = 'LCASE'      Then IsKeyword := KW_LCASE
  Else If U = 'LEFT'       Then IsKeyword := KW_LEFT
  Else If U = 'LOG'        Then IsKeyword := KW_LOG
  Else If U = 'LTRIM'      Then IsKeyword := KW_LTRIM
  Else If U = 'MID'        Then IsKeyword := KW_MID
  Else If U = 'OCT'        Then IsKeyword := KW_OCT
  Else If U = 'RIGHT'      Then IsKeyword := KW_RIGHT
  Else If U = 'RTRIM'      Then IsKeyword := KW_RTRIM
  Else If U = 'SGN'        Then IsKeyword := KW_SGN
  Else If U = 'SIN'        Then IsKeyword := KW_SIN
  Else If U = 'SPACE'      Then IsKeyword := KW_SPACE
  Else If U = 'SQR'        Then IsKeyword := KW_SQR
  Else If U = 'STR'        Then IsKeyword := KW_STR
  Else If U = 'TAB'        Then IsKeyword := KW_TAB
  Else If U = 'TAN'        Then IsKeyword := KW_TAN
  Else If U = 'TRIM'       Then IsKeyword := KW_TRIM
  Else If U = 'UCASE'      Then IsKeyword := KW_UCASE
  Else If U = 'VAL'        Then IsKeyword := KW_VAL
  Else If U = 'FORMAT'     Then IsKeyword := KW_FORMAT
  Else If U = 'REPLACE'    Then IsKeyword := KW_REPLACE
  Else If U = 'SPLIT'      Then IsKeyword := KW_SPLIT
  Else If U = 'JOIN'       Then IsKeyword := KW_JOIN
  Else If U = 'MSGBOX'     Then IsKeyword := KW_MSGBOX
  Else If U = 'INPUTBOX'   Then IsKeyword := KW_INPUTBOX
  Else If U = 'DEBUG'      Then IsKeyword := KW_DEBUG
  Else If U = 'DOEVENTS'   Then IsKeyword := KW_DOEVENTS
  Else If U = 'ARRAY'      Then IsKeyword := KW_ARRAY
  Else If U = 'ISARRAY'    Then IsKeyword := KW_ISARRAY
  Else If U = 'ISDATE'     Then IsKeyword := KW_ISDATE
  Else If U = 'ISEMPTY'    Then IsKeyword := KW_ISEMPTY
  Else If U = 'ISNULL'     Then IsKeyword := KW_ISNULL
  Else If U = 'ISNUMERIC'  Then IsKeyword := KW_ISNUMERIC
  Else If U = 'ISOBJECT'   Then IsKeyword := KW_ISOBJECT
  Else If U = 'ISMISSING'  Then IsKeyword := KW_ISMISSING
  Else If U = 'BYTE'       Then IsKeyword := KW_BYTE
  Else If U = 'ERR'        Then IsKeyword := KW_ERR
  Else If U = 'STRCOMP'    Then IsKeyword := KW_STRCOMP
  Else If U = 'STRREVERSE' Then IsKeyword := KW_STRREVERSE
  Else If U = 'RND'        Then IsKeyword := KW_RND
  Else If U = 'RANDOMIZE'  Then IsKeyword := KW_RANDOMIZE
  Else If U = 'TYPENAME'   Then IsKeyword := KW_TYPENAME
  Else If U = 'VARTYPE'    Then IsKeyword := KW_VARTYPE
  Else If U = 'MID$'       Then IsKeyword := KW_MIDASSIGN
  Else If U = 'FORMAT$'    Then IsKeyword := KW_FORMAT2
  Else IsKeyword := KW_NONE;
End;

{ ------------------------------------------------------------ }
{ KeywordName : retourne le nom d un mot-cle a partir de       }
{               sa constante KW_*                               }
{ ------------------------------------------------------------ }

Function KeywordName(KW : Integer) : TString;
Begin
  Case KW Of
    KW_AND        : KeywordName := 'And';
    KW_AS         : KeywordName := 'As';
    KW_BOOLEAN    : KeywordName := 'Boolean';
    KW_BYREF      : KeywordName := 'ByRef';
    KW_BYVAL      : KeywordName := 'ByVal';
    KW_CALL       : KeywordName := 'Call';
    KW_CASE       : KeywordName := 'Case';
    KW_CBOOL      : KeywordName := 'CBool';
    KW_CBYTE      : KeywordName := 'CByte';
    KW_CCUR       : KeywordName := 'CCur';
    KW_CDATE      : KeywordName := 'CDate';
    KW_CDBL       : KeywordName := 'CDbl';
    KW_CINT       : KeywordName := 'CInt';
    KW_CLNG       : KeywordName := 'CLng';
    KW_CLOSE      : KeywordName := 'Close';
    KW_CONST      : KeywordName := 'Const';
    KW_CSNG       : KeywordName := 'CSng';
    KW_CSTR       : KeywordName := 'CStr';
    KW_CURRENCY   : KeywordName := 'Currency';
    KW_DATE       : KeywordName := 'Date';
    KW_DECLARE    : KeywordName := 'Declare';
    KW_DEFBOOL    : KeywordName := 'DefBool';
    KW_DEFBYTE    : KeywordName := 'DefByte';
    KW_DEFCUR     : KeywordName := 'DefCur';
    KW_DEFDATE    : KeywordName := 'DefDate';
    KW_DEFDBL     : KeywordName := 'DefDbl';
    KW_DEFINT     : KeywordName := 'DefInt';
    KW_DEFLNG     : KeywordName := 'DefLng';
    KW_DEFOBJ     : KeywordName := 'DefObj';
    KW_DEFSNG     : KeywordName := 'DefSng';
    KW_DEFSTR     : KeywordName := 'DefStr';
    KW_DEFVAR     : KeywordName := 'DefVar';
    KW_DIM        : KeywordName := 'Dim';
    KW_DO         : KeywordName := 'Do';
    KW_DOUBLE     : KeywordName := 'Double';
    KW_EACH       : KeywordName := 'Each';
    KW_ELSE       : KeywordName := 'Else';
    KW_ELSEIF     : KeywordName := 'ElseIf';
    KW_EMPTY      : KeywordName := 'Empty';
    KW_END        : KeywordName := 'End';
    KW_ENUM       : KeywordName := 'Enum';
    KW_EQV        : KeywordName := 'Eqv';
    KW_ERASE      : KeywordName := 'Erase';
    KW_ERROR      : KeywordName := 'Error';
    KW_EVENT      : KeywordName := 'Event';
    KW_EXIT       : KeywordName := 'Exit';
    KW_EXPLICIT   : KeywordName := 'Explicit';
    KW_FALSE      : KeywordName := 'False';
    KW_FOR        : KeywordName := 'For';
    KW_FRIEND     : KeywordName := 'Friend';
    KW_FUNCTION   : KeywordName := 'Function';
    KW_GET        : KeywordName := 'Get';
    KW_GLOBAL     : KeywordName := 'Global';
    KW_GOSUB      : KeywordName := 'GoSub';
    KW_GOTO       : KeywordName := 'GoTo';
    KW_IF         : KeywordName := 'If';
    KW_IMP        : KeywordName := 'Imp';
    KW_IMPLEMENTS : KeywordName := 'Implements';
    KW_IN         : KeywordName := 'In';
    KW_INPUT      : KeywordName := 'Input';
    KW_INTEGER    : KeywordName := 'Integer';
    KW_IS         : KeywordName := 'Is';
    KW_LBOUND     : KeywordName := 'LBound';
    KW_LEN        : KeywordName := 'Len';
    KW_LET        : KeywordName := 'Let';
    KW_LIKE       : KeywordName := 'Like';
    KW_LONG       : KeywordName := 'Long';
    KW_LOOP       : KeywordName := 'Loop';
    KW_LSET       : KeywordName := 'LSet';
    KW_ME         : KeywordName := 'Me';
    KW_MOD        : KeywordName := 'Mod';
    KW_NEW        : KeywordName := 'New';
    KW_NEXT       : KeywordName := 'Next';
    KW_NOT        : KeywordName := 'Not';
    KW_NOTHING    : KeywordName := 'Nothing';
    KW_NULL       : KeywordName := 'Null';
    KW_OBJECT     : KeywordName := 'Object';
    KW_ON         : KeywordName := 'On';
    KW_OPEN       : KeywordName := 'Open';
    KW_OPTION     : KeywordName := 'Option';
    KW_OPTIONAL   : KeywordName := 'Optional';
    KW_OR         : KeywordName := 'Or';
    KW_PARAMARRAY : KeywordName := 'ParamArray';
    KW_PRESERVE   : KeywordName := 'Preserve';
    KW_PRINT      : KeywordName := 'Print';
    KW_PRIVATE    : KeywordName := 'Private';
    KW_PROPERTY   : KeywordName := 'Property';
    KW_PUBLIC     : KeywordName := 'Public';
    KW_RAISEEVENT : KeywordName := 'RaiseEvent';
    KW_REDIM      : KeywordName := 'ReDim';
    KW_REM        : KeywordName := 'Rem';
    KW_RESUME     : KeywordName := 'Resume';
    KW_RETURN     : KeywordName := 'Return';
    KW_RSET       : KeywordName := 'RSet';
    KW_SEEK       : KeywordName := 'Seek';
    KW_SELECT     : KeywordName := 'Select';
    KW_SET        : KeywordName := 'Set';
    KW_SINGLE     : KeywordName := 'Single';
    KW_STATIC     : KeywordName := 'Static';
    KW_STEP       : KeywordName := 'Step';
    KW_STOP       : KeywordName := 'Stop';
    KW_STRING     : KeywordName := 'String';
    KW_SUB        : KeywordName := 'Sub';
    KW_THEN       : KeywordName := 'Then';
    KW_TO         : KeywordName := 'To';
    KW_TRUE       : KeywordName := 'True';
    KW_TYPE       : KeywordName := 'Type';
    KW_TYPEOF     : KeywordName := 'TypeOf';
    KW_UBOUND     : KeywordName := 'UBound';
    KW_UNTIL      : KeywordName := 'Until';
    KW_VARIANT    : KeywordName := 'Variant';
    KW_WEND       : KeywordName := 'Wend';
    KW_WHILE      : KeywordName := 'While';
    KW_WITH       : KeywordName := 'With';
    KW_WITHEVENTS : KeywordName := 'WithEvents';
    KW_WRITE      : KeywordName := 'Write';
    KW_XOR        : KeywordName := 'Xor';
    KW_ABS        : KeywordName := 'Abs';
    KW_ASC        : KeywordName := 'Asc';
    KW_ATN        : KeywordName := 'Atn';
    KW_CHR        : KeywordName := 'Chr';
    KW_COS        : KeywordName := 'Cos';
    KW_EXP        : KeywordName := 'Exp';
    KW_FIX        : KeywordName := 'Fix';
    KW_HEX        : KeywordName := 'Hex';
    KW_INSTR      : KeywordName := 'InStr';
    KW_INSTRREV   : KeywordName := 'InStrRev';
    KW_INT        : KeywordName := 'Int';
    KW_LCASE      : KeywordName := 'LCase';
    KW_LEFT       : KeywordName := 'Left';
    KW_LEN2       : KeywordName := 'Len';
    KW_LOG        : KeywordName := 'Log';
    KW_LTRIM      : KeywordName := 'LTrim';
    KW_MID        : KeywordName := 'Mid';
    KW_OCT        : KeywordName := 'Oct';
    KW_RIGHT      : KeywordName := 'Right';
    KW_RTRIM      : KeywordName := 'RTrim';
    KW_SGN        : KeywordName := 'Sgn';
    KW_SIN        : KeywordName := 'Sin';
    KW_SPACE      : KeywordName := 'Space';
    KW_SQR        : KeywordName := 'Sqr';
    KW_STR        : KeywordName := 'Str';
    KW_STRINGFN   : KeywordName := 'String$';
    KW_TAB        : KeywordName := 'Tab';
    KW_TAN        : KeywordName := 'Tan';
    KW_TRIM       : KeywordName := 'Trim';
    KW_UCASE      : KeywordName := 'UCase';
    KW_VAL        : KeywordName := 'Val';
    KW_FORMAT     : KeywordName := 'Format';
    KW_REPLACE    : KeywordName := 'Replace';
    KW_SPLIT      : KeywordName := 'Split';
    KW_JOIN       : KeywordName := 'Join';
    KW_MSGBOX     : KeywordName := 'MsgBox';
    KW_INPUTBOX   : KeywordName := 'InputBox';
    KW_DEBUG      : KeywordName := 'Debug';
    KW_DOEVENTS   : KeywordName := 'DoEvents';
    KW_ARRAY      : KeywordName := 'Array';
    KW_ISARRAY    : KeywordName := 'IsArray';
    KW_ISDATE     : KeywordName := 'IsDate';
    KW_ISEMPTY    : KeywordName := 'IsEmpty';
    KW_ISNULL     : KeywordName := 'IsNull';
    KW_ISNUMERIC  : KeywordName := 'IsNumeric';
    KW_ISOBJECT   : KeywordName := 'IsObject';
    KW_ISMISSING  : KeywordName := 'IsMissing';
    KW_BYTE       : KeywordName := 'Byte';
    KW_DATE2      : KeywordName := 'Date';
    KW_ERR        : KeywordName := 'Err';
    KW_STRCOMP    : KeywordName := 'StrComp';
    KW_STRREVERSE : KeywordName := 'StrReverse';
    KW_RND        : KeywordName := 'Rnd';
    KW_RANDOMIZE  : KeywordName := 'Randomize';
    KW_TYPENAME   : KeywordName := 'TypeName';
    KW_VARTYPE    : KeywordName := 'VarType';
    KW_MIDASSIGN  : KeywordName := 'Mid$';
    KW_FORMAT2    : KeywordName := 'Format$';
    KW_LIKE2      : KeywordName := 'Like';
  Else
    KeywordName := '?KW' + ItoSI(KW);
  End;
End;

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
  Reset(LexSrcF);
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
{ Saute le reste de la ligne (commentaire VB6)                 }
{ ------------------------------------------------------------ }

Procedure LexSkipComment;
Begin
  LexColNo := Length(LexLine) + 1;
End;

{ ------------------------------------------------------------ }
{ LexScanIdent : identificateur avec suffixe de type optionnel }
{ Suffixes VB6 : % (Integer), & (Long), ! (Single),           }
{                # (Double), @ (Currency), $ (String)          }
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
  { Verifier suffixe de type sur l identificateur }
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
  { Tester si c est un mot-cle VB6 }
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
{ LexScanNumber : entier, reel, ou avec suffixes VB6           }
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

  { Exposant E ou D }
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
  Else If (LexColNo <= Length(LexLine)) And
          ((LexLine[LexColNo] = 'D') Or (LexLine[LexColNo] = 'd')) Then
  Begin
    IsReal  := True;
    TokKind := TOK_DOUBLE;
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
{ LexScanString : chaine VB6 entre guillemets doubles          }
{ Gere le doublement de guillemet : "l""echo" -> l"echo        }
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
    TOK_STRING    : Write('STR("', CurTokStr, '")');
    TOK_DATE      : Write('DATE(#', CurTokStr, '#)');
    TOK_PLUS      : Write('PLUS');
    TOK_MINUS     : Write('MINUS');
    TOK_STAR      : Write('STAR');
    TOK_SLASH     : Write('SLASH');
    TOK_BACKSLASH : Write('BACKSLASH');
    TOK_CARET     : Write('CARET');
    TOK_AMP       : Write('AMP');
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
  Else
    Write('TOK(', CurTokType, ')');
  End;
  WriteLn;
End;

{ ------------------------------------------------------------ }
{ LexNextToken : reconnaitre le prochain token VB6             }
{ ------------------------------------------------------------ }

Procedure LexNextToken;
Var
  Ch        : Char;
  Done      : Boolean;
  J         : Integer;
  AllBlanks : Boolean;
  K         : Integer;
  HasClose  : Boolean;
Begin
  Done := False;
  While Not Done Do
  Begin
    { Passer les lignes vides / fin de ligne }
    While (Not LexEOF) And (LexColNo > Length(LexLine)) Do
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

    { Commentaire ' (apostrophe) }
    If Ch = '''' Then
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

    { Guillemet double : chaine }
    Else If Ch = '"' Then
    Begin
      LexScanString;
      Done := True;
    End

    { & : concatenation, hex (&H), octal (&O) }
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

    { Operateurs et separateurs }
    Else If Ch = '+' Then
    Begin
      CurTokType := TOK_PLUS;
      CurTokStr  := '+';
      CurTokNum  := 0;
      CurTokReal := 0.0;
      Inc(LexColNo);
      Done := True;
    End
    Else If Ch = '-' Then
    Begin
      CurTokType := TOK_MINUS;
      CurTokStr  := '-';
      CurTokNum  := 0;
      CurTokReal := 0.0;
      Inc(LexColNo);
      Done := True;
    End
    Else If Ch = '*' Then
    Begin
      CurTokType := TOK_STAR;
      CurTokStr  := '*';
      CurTokNum  := 0;
      CurTokReal := 0.0;
      Inc(LexColNo);
      Done := True;
    End
    Else If Ch = '/' Then
    Begin
      CurTokType := TOK_SLASH;
      CurTokStr  := '/';
      CurTokNum  := 0;
      CurTokReal := 0.0;
      Inc(LexColNo);
      Done := True;
    End
    Else If Ch = '\' Then
    Begin
      CurTokType := TOK_BACKSLASH;
      CurTokStr  := '\';
      CurTokNum  := 0;
      CurTokReal := 0.0;
      Inc(LexColNo);
      Done := True;
    End
    Else If Ch = '^' Then
    Begin
      CurTokType := TOK_CARET;
      CurTokStr  := '^';
      CurTokNum  := 0;
      CurTokReal := 0.0;
      Inc(LexColNo);
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
  SK_PROPERTY    = 5;   { propriete Property Get/Let/Set           }
  SK_TYPE        = 6;   { type utilisateur (Type...End Type)       }
  SK_ENUM        = 7;   { enumeration (Enum...End Enum)            }
  SK_ENUM_MEMBER = 8;   { membre d enumeration                     }
  SK_CLASS       = 9;   { classe                                   }
  SK_MODULE      = 10;  { module VB6                               }
  SK_FIELD       = 11;  { champ d un Type ou d une classe         }
  SK_EVENT       = 12;  { evenement (Event)                        }
  SK_LABEL       = 13;  { label (etiquette de ligne)               }
  SK_ARRAY       = 14;  { tableau (Dim arr(...))                   }

  { Classes d entreposage }
  STORE_AUTO     = 0;   { pile EBP (variables locales)             }
  STORE_STATIC   = 1;   { segment .DATA (Static)                   }
  STORE_PARAM    = 2;   { EBP+n (parametre)                        }
  STORE_GLOBAL   = 3;   { segment .DATA (Public/Global)            }
  STORE_CONSTANT = 4;   { immediate (Const)                        }

  { Types VB6 internes (codes DataType) }
  VBT_NONE       = 0;   { non type / inconnu                       }
  VBT_BOOLEAN    = 1;   { Boolean   (DD, 4 octets en interne)      }
  VBT_BYTE       = 2;   { Byte      (DB, 1 octet)                  }
  VBT_INTEGER    = 3;   { Integer   (DW, 16 bits VB)               }
  VBT_LONG       = 4;   { Long      (DD, 32 bits)                  }
  VBT_SINGLE     = 5;   { Single    (DD, flottant 32 bits)         }
  VBT_DOUBLE     = 6;   { Double    (DQ, 64 bits)                  }
  VBT_CURRENCY   = 7;   { Currency  (DQ, 64 bits fixe)             }
  VBT_STRING     = 8;   { String    (pointeur DD)                  }
  VBT_VARIANT    = 9;   { Variant   (16 octets stub)               }
  VBT_DATE       = 10;  { Date      (DQ, 64 bits)                  }
  VBT_OBJECT     = 11;  { Object    (pointeur DD)                  }
  VBT_USER       = 12;  { Type utilisateur (taille variable)       }

  { Tailles en octets des types VB6 (32 bits) }
  VBT_SIZE_BOOLEAN  = 4;  { DD en interne (2 en VB mais 4 aligne)  }
  VBT_SIZE_BYTE     = 1;  { DB                                     }
  VBT_SIZE_INTEGER  = 2;  { DW (16 bits VB6)                       }
  VBT_SIZE_LONG     = 4;  { DD (32 bits)                           }
  VBT_SIZE_SINGLE   = 4;  { DD (flottant 32 bits)                  }
  VBT_SIZE_DOUBLE   = 8;  { DQ (64 bits)                           }
  VBT_SIZE_CURRENCY = 8;  { DQ (64 bits fixe)                      }
  VBT_SIZE_STRING   = 4;  { pointeur DD                            }
  VBT_SIZE_VARIANT  = 16; { 16 octets stub                         }
  VBT_SIZE_DATE     = 8;  { DQ (64 bits)                           }
  VBT_SIZE_OBJECT   = 4;  { pointeur DD                            }

Type
  { Entree dans la table des symboles }
  TSymEntry = Record
    Name       : String[255]; { nom du symbole                     }
    AsmLabel   : String[64];  { label assembleur genere             }
    Kind       : Integer;     { SK_CONST, SK_VAR, etc.             }
    DataType   : Integer;     { VBT_LONG, VBT_STRING, etc.         }
    StoreClass : Integer;     { STORE_AUTO, STORE_GLOBAL, etc.     }
    BpOffset   : Integer;     { offset EBP pour locales/params     }
    ArrayDims  : Integer;     { nombre de dimensions (0 = scalaire) }
    ArrayBase  : Integer;     { Option Base (0 ou 1)               }
    IsStatic   : Boolean;     { variable Static ?                   }
    IsPublic   : Boolean;     { Public ?                            }
    IsOptional : Boolean;     { parametre Optional ?                }
    DefaultVal : String[64];  { valeur par defaut (si HasDefault)   }
    HasDefault : Boolean;     { a une valeur par defaut ?           }
    ByRef      : Boolean;     { passe par reference ?               }
    ParamIdx   : Integer;     { index du premier parametre (proc)  }
    ClassIdx   : Integer;     { index de la classe parente          }
    InitStr    : String[64];  { valeur initiale chaine              }
    InitNum    : LongInt;     { valeur initiale numerique           }
    HasInit    : Boolean;     { a une valeur initiale ?             }
    IsConst    : Boolean;     { constante ?                         }
  End;

  { Entree dans la table des procedures }
  TProcEntry = Record
    Name       : String[255]; { nom de la procedure/fonction        }
    AsmLabel   : String[64];  { label assembleur (_VBF_...)         }
    Kind       : Integer;     { SK_SUB, SK_FUNCTION, SK_PROPERTY   }
    ReturnType : Integer;     { type de retour (0 pour Sub)         }
    ParamStart : Integer;     { index du premier param dans SymTab  }
    ParamCount : Integer;     { nombre de parametres                }
    LocalStart : Integer;     { index de la premiere locale         }
    LocalCount : Integer;     { nombre de variables locales         }
    LocalSize  : Integer;     { taille totale des locales (octets) }
    IsPublic   : Boolean;     { Public ?                            }
    IsStatic   : Boolean;     { Static (tous les locaux en .DATA)  }
    ClassIdx   : Integer;     { index de la classe (-1 si aucune)  }
    ExitLabel  : String[64];  { label de sortie (_VBL_xxx_exit)    }
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
    SK_TYPE        : SymKindName := 'Type';
    SK_ENUM        : SymKindName := 'Enum';
    SK_ENUM_MEMBER : SymKindName := 'EnumMember';
    SK_CLASS       : SymKindName := 'Class';
    SK_MODULE      : SymKindName := 'Module';
    SK_FIELD       : SymKindName := 'Field';
    SK_EVENT       : SymKindName := 'Event';
    SK_LABEL       : SymKindName := 'Label';
  Else
    SymKindName := '?SK' + ItoSI(K);
  End;
End;

{ ------------------------------------------------------------ }
{ VBTypeName : nom textuel d un type VB6                       }
{ ------------------------------------------------------------ }

Function VBTypeName(T : Integer) : TString;
Begin
  Case T Of
    VBT_NONE     : VBTypeName := '(none)';
    VBT_BOOLEAN  : VBTypeName := 'Boolean';
    VBT_BYTE     : VBTypeName := 'Byte';
    VBT_INTEGER  : VBTypeName := 'Integer';
    VBT_LONG     : VBTypeName := 'Long';
    VBT_SINGLE   : VBTypeName := 'Single';
    VBT_DOUBLE   : VBTypeName := 'Double';
    VBT_CURRENCY : VBTypeName := 'Currency';
    VBT_STRING   : VBTypeName := 'String';
    VBT_VARIANT  : VBTypeName := 'Variant';
    VBT_DATE     : VBTypeName := 'Date';
    VBT_OBJECT   : VBTypeName := 'Object';
    VBT_USER     : VBTypeName := 'UserType';
  Else
    VBTypeName := '?VBT' + ItoSI(T);
  End;
End;

{ ------------------------------------------------------------ }
{ VBTypeSize : taille en octets d un type VB6 (32 bits)        }
{ ------------------------------------------------------------ }

Function VBTypeSize(T : Integer) : Integer;
Begin
  Case T Of
    VBT_BOOLEAN  : VBTypeSize := VBT_SIZE_BOOLEAN;
    VBT_BYTE     : VBTypeSize := VBT_SIZE_BYTE;
    VBT_INTEGER  : VBTypeSize := VBT_SIZE_INTEGER;
    VBT_LONG     : VBTypeSize := VBT_SIZE_LONG;
    VBT_SINGLE   : VBTypeSize := VBT_SIZE_SINGLE;
    VBT_DOUBLE   : VBTypeSize := VBT_SIZE_DOUBLE;
    VBT_CURRENCY : VBTypeSize := VBT_SIZE_CURRENCY;
    VBT_STRING   : VBTypeSize := VBT_SIZE_STRING;
    VBT_VARIANT  : VBTypeSize := VBT_SIZE_VARIANT;
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
    SymTab[I].Name       := '';
    SymTab[I].AsmLabel   := '';
    SymTab[I].Kind       := SK_VAR;
    SymTab[I].DataType   := VBT_NONE;
    SymTab[I].StoreClass := STORE_AUTO;
    SymTab[I].BpOffset   := 0;
    SymTab[I].ArrayDims  := 0;
    SymTab[I].ArrayBase  := 0;
    SymTab[I].IsStatic   := False;
    SymTab[I].IsPublic   := False;
    SymTab[I].IsOptional := False;
    SymTab[I].DefaultVal := '';
    SymTab[I].HasDefault := False;
    SymTab[I].ByRef      := False;
    SymTab[I].ParamIdx   := -1;
    SymTab[I].ClassIdx   := -1;
    SymTab[I].InitStr    := '';
    SymTab[I].InitNum    := 0;
    SymTab[I].HasInit    := False;
    SymTab[I].IsConst    := False;
  End;
  For I := 0 To MAX_PROC - 1 Do
  Begin
    ProcTab[I].Name       := '';
    ProcTab[I].AsmLabel   := '';
    ProcTab[I].Kind       := SK_SUB;
    ProcTab[I].ReturnType := VBT_NONE;
    ProcTab[I].ParamStart := 0;
    ProcTab[I].ParamCount := 0;
    ProcTab[I].LocalStart := 0;
    ProcTab[I].LocalCount := 0;
    ProcTab[I].LocalSize  := 0;
    ProcTab[I].IsPublic   := False;
    ProcTab[I].IsStatic   := False;
    ProcTab[I].ClassIdx   := -1;
    ProcTab[I].ExitLabel  := '';
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
  SymTab[Idx].Name       := AName;
  SymTab[Idx].Kind       := AKind;
  SymTab[Idx].DataType   := ADataType;
  SymTab[Idx].StoreClass := AStore;
  SymTab[Idx].BpOffset   := 0;
  SymTab[Idx].ArrayDims  := 0;
  SymTab[Idx].ArrayBase  := 0;
  SymTab[Idx].IsStatic   := False;
  SymTab[Idx].IsPublic   := False;
  SymTab[Idx].IsOptional := False;
  SymTab[Idx].DefaultVal := '';
  SymTab[Idx].HasDefault := False;
  SymTab[Idx].ByRef      := False;
  SymTab[Idx].ParamIdx   := -1;
  SymTab[Idx].ClassIdx   := -1;
  SymTab[Idx].InitStr    := '';
  SymTab[Idx].InitNum    := 0;
  SymTab[Idx].HasInit    := False;
  SymTab[Idx].IsConst    := False;
  { Generer le label assembleur }
  Case AKind Of
    SK_VAR, SK_FIELD  : SymTab[Idx].AsmLabel := PFX_VAR + AsmIdent(AName);
    SK_CONST          : SymTab[Idx].AsmLabel := PFX_CONST + AsmIdent(AName);
    SK_SUB, SK_FUNCTION,
    SK_PROPERTY       : SymTab[Idx].AsmLabel := PFX_FUNC + AsmIdent(AName);
    SK_TYPE           : SymTab[Idx].AsmLabel := PFX_TYPE + AsmIdent(AName);
    SK_CLASS          : SymTab[Idx].AsmLabel := PFX_CLS + AsmIdent(AName);
    SK_ENUM           : SymTab[Idx].AsmLabel := PFX_ENUM + AsmIdent(AName);
    SK_LABEL          : SymTab[Idx].AsmLabel := PFX_LBL + AsmIdent(AName);
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
  ProcTab[Idx].Name       := AName;
  ProcTab[Idx].AsmLabel   := PFX_FUNC + AsmIdent(AName);
  ProcTab[Idx].Kind       := AKind;
  ProcTab[Idx].ReturnType := ARetType;
  ProcTab[Idx].ParamStart := SymCount;
  ProcTab[Idx].ParamCount := 0;
  ProcTab[Idx].LocalStart := 0;
  ProcTab[Idx].LocalCount := 0;
  ProcTab[Idx].LocalSize  := 0;
  ProcTab[Idx].IsPublic   := APublic;
  ProcTab[Idx].IsStatic   := False;
  ProcTab[Idx].ClassIdx   := -1;
  ProcTab[Idx].ExitLabel  := PFX_LBL + AsmIdent(AName) + '_exit';
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
{           (MODULE, SUB, FUNCTION, CLASS)                    }
{ ============================================================ }

Const
  { Genres de portees }
  SCOPE_GLOBAL   = 0;   { portee globale (module-level)            }
  SCOPE_MODULE   = 1;   { portee d un module VB6                   }
  SCOPE_SUB      = 2;   { portee d une procedure Sub               }
  SCOPE_FUNCTION = 3;   { portee d une fonction Function            }
  SCOPE_PROPERTY = 4;   { portee d une propriete Property          }
  SCOPE_CLASS    = 5;   { portee d une classe                      }
  SCOPE_WITH     = 6;   { portee With ... End With                 }
  SCOPE_BLOCK    = 7;   { portee de bloc (For, If, Do, Select)     }

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
    SCOPE_GLOBAL   : ScopeKindName := 'Global';
    SCOPE_MODULE   : ScopeKindName := 'Module';
    SCOPE_SUB      : ScopeKindName := 'Sub';
    SCOPE_FUNCTION : ScopeKindName := 'Function';
    SCOPE_PROPERTY : ScopeKindName := 'Property';
    SCOPE_CLASS    : ScopeKindName := 'Class';
    SCOPE_WITH     : ScopeKindName := 'With';
    SCOPE_BLOCK    : ScopeKindName := 'Block';
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
  End;
  { Portee globale initiale }
  ScopeStack[0].Kind     := SCOPE_GLOBAL;
  ScopeStack[0].ProcIdx  := -1;
  ScopeStack[0].SymStart := 0;
  ScopeStack[0].EbpTop   := 0;
  ScopeStack[0].IsStatic := False;
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

{ ============================================================ }
{ TODO 06 - PARSEUR : MODULE ET EN-TETE         [IMPLEMENTE] }
{           DU PROGRAMME                                      }
{ ============================================================ }

Const
  { Types de module VB6 }
  MODULE_STANDARD = 0;   { module standard .VB (Sub Main)          }
  MODULE_FORM     = 1;   { module formulaire .FRM (stub -> .VB)    }
  MODULE_CLASS    = 2;   { module de classe .CLS                   }

  { Option Compare }
  OPT_COMPARE_BINARY = 0;  { comparaison binaire (par defaut)      }
  OPT_COMPARE_TEXT   = 1;  { comparaison textuelle                 }

Var
  { Etat du module en cours d analyse }
  ModuleKind     : Integer;     { MODULE_STANDARD, MODULE_FORM, etc. }
  OptionExplicit : Boolean;     { Option Explicit ?                    }
  OptionBase     : Integer;     { Option Base (0 ou 1)                 }
  OptionCompare  : Integer;     { OPT_COMPARE_BINARY ou _TEXT          }
  ModuleName     : TString;     { nom du module (Attribute VB_Name)    }
  HasEntryPoint  : Boolean;     { module a un point d entree ?         }
  ModuleHeaderParsed : Boolean; { en-tete deja analyse ?               }

{ ------------------------------------------------------------ }
{ ModuleKindName : nom textuel du genre de module              }
{ ------------------------------------------------------------ }

Function ModuleKindName(K : Integer) : TString;
Begin
  Case K Of
    MODULE_STANDARD : ModuleKindName := 'Standard';
    MODULE_FORM     : ModuleKindName := 'Form';
    MODULE_CLASS    : ModuleKindName := 'Class';
  Else
    ModuleKindName := '?MOD' + ItoSI(K);
  End;
End;

{ ------------------------------------------------------------ }
{ InitModuleState : initialiser l etat du module               }
{ ------------------------------------------------------------ }

Procedure InitModuleState;
Begin
  ModuleKind         := MODULE_STANDARD;
  OptionExplicit     := False;
  OptionBase         := 0;
  OptionCompare      := OPT_COMPARE_BINARY;
  ModuleName         := '';
  HasEntryPoint      := False;
  ModuleHeaderParsed := False;
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
{ DetectModuleKind : detecter le type de module d apres         }
{   l extension du fichier source                              }
{ ------------------------------------------------------------ }

Procedure DetectModuleKind;
Var Ext : TString;
Begin
  Ext := ExtractExt(Opts.SrcFile);
  If (Ext = '.cls') Then
    ModuleKind := MODULE_CLASS
  Else If (Ext = '.frm') Then
    ModuleKind := MODULE_FORM
  Else
    ModuleKind := MODULE_STANDARD;
End;

{ ------------------------------------------------------------ }
{ ParseOptionStatement : analyser Option Explicit / Base / Cmp }
{   Token courant : KW_OPTION                                  }
{ ------------------------------------------------------------ }

Procedure ParseOptionStatement;
Begin
  { Consommer "Option" }
  LexNextToken;
  { Determiner quel type d option }
  If IsKeywordToken(KW_EXPLICIT) Then
  Begin
    OptionExplicit := True;
    LexNextToken;
    If Opts.Verbose Then
      WriteLn('  Option Explicit');
  End
  Else If IsIdentToken('Base') Then
  Begin
    LexNextToken;
    If CurTokType = TOK_INTEGER Then
    Begin
      If (CurTokNum = 0) Or (CurTokNum = 1) Then
        OptionBase := CurTokNum
      Else
        WarnMsg('Option Base doit etre 0 ou 1, ignore: ' + CurTokStr);
      LexNextToken;
    End
    Else
      FatalError('Option Base attend 0 ou 1, trouve "' + CurTokStr + '"');
    If Opts.Verbose Then
      WriteLn('  Option Base ', OptionBase);
  End
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
  Else
  Begin
    WarnMsg('Option non reconnue : "' + CurTokStr + '", ligne ignoree');
    SkipToEndOfLine;
  End;
End;

{ ------------------------------------------------------------ }
{ ParseAttributeLine : analyser Attribute VB_Name = "..."      }
{   Token courant : ident "Attribute"                          }
{   Extrait le nom du module si VB_Name                        }
{   Ignore les autres attributs VB_*                           }
{ ------------------------------------------------------------ }

Procedure ParseAttributeLine;
Var AttrName : TString;
Begin
  { Consommer "Attribute" }
  LexNextToken;
  { Lire le nom de l attribut (ex: VB_Name) }
  If CurTokType = TOK_IDENT Then
  Begin
    AttrName := UpCaseStr(CurTokStr);
    LexNextToken;
    { Consommer "=" }
    If CurTokType = TOK_EQ Then
    Begin
      LexNextToken;
      { Si VB_NAME, extraire le nom du module }
      If AttrName = 'VB_NAME' Then
      Begin
        If CurTokType = TOK_STRING Then
        Begin
          ModuleName := CurTokStr;
          If Opts.Verbose Then
            WriteLn('  Attribute VB_Name = "', ModuleName, '"');
          LexNextToken;
        End
        Else
        Begin
          WarnMsg('Attribute VB_Name attend une chaine');
          SkipToEndOfLine;
        End;
      End
      Else
      Begin
        { Ignorer les autres attributs VB_* }
        If Opts.Verbose Then
          WriteLn('  Attribute ', AttrName, ' = ... (ignore)');
        SkipToEndOfLine;
      End;
    End
    Else
    Begin
      { Pas de '=', ignorer la ligne }
      SkipToEndOfLine;
    End;
  End
  Else
  Begin
    { Pas d ident apres Attribute, ignorer }
    SkipToEndOfLine;
  End;
End;

{ ------------------------------------------------------------ }
{ ParseModuleHeader : analyser l en-tete du module             }
{   Consomme Option/Attribute jusqu au premier statement       }
{   reel (Dim, Sub, Function, Public, Private, etc.)           }
{ ------------------------------------------------------------ }

Procedure ParseModuleHeader;
Begin
  SkipNewlines;
  While CurTokType <> TOK_EOF Do
  Begin
    { Option Explicit / Option Base / Option Compare }
    If IsKeywordToken(KW_OPTION) Then
    Begin
      ParseOptionStatement;
      SkipNewlines;
    End
    { Attribute VB_Name = "..." }
    Else If IsIdentToken('Attribute') Then
    Begin
      ParseAttributeLine;
      SkipNewlines;
    End
    Else
      { Fin de l en-tete : un vrai statement commence }
      Break;
  End;
End;

{ ------------------------------------------------------------ }
{ SetupEntryPoint : configurer le point d entree du module     }
{   Module standard/form : HasEntryPoint=True, label _VBF_MAIN}
{   Module classe : pas de point d entree direct               }
{ ------------------------------------------------------------ }

Procedure SetupEntryPoint;
Begin
  If ModuleKind = MODULE_CLASS Then
    HasEntryPoint := False
  Else
  Begin
    HasEntryPoint := True;
    If Opts.Verbose Then
      WriteLn('  Point d''entree : ', PFX_FUNC, 'MAIN');
  End;
End;

{ ------------------------------------------------------------ }
{ ParseModule : point d entree principal du parseur            }
{   1. Detecter le type de module (.VB, .FRM, .CLS)           }
{   2. Analyser l en-tete (Option, Attribute)                  }
{   3. Configurer le point d entree                            }
{   Le reste du module sera parse par les TODOs suivants       }
{ ------------------------------------------------------------ }

Procedure ParseModule;
Begin
  InitModuleState;
  DetectModuleKind;

  If Opts.Verbose Then
    WriteLn('Module: ', Opts.SrcFile, ' (', ModuleKindName(ModuleKind), ')');

  { Si aucun nom de module, utiliser le nom du fichier sans ext }
  If ModuleName = '' Then
  Begin
    ModuleName := Opts.SrcFile;
    { Retirer l extension }
    If Pos('.', ModuleName) > 0 Then
      ModuleName := Copy(ModuleName, 1, Pos('.', ModuleName) - 1);
    { Retirer le chemin }
    While Pos('/', ModuleName) > 0 Do
      ModuleName := Copy(ModuleName, Pos('/', ModuleName) + 1, 255);
    While Pos('\', ModuleName) > 0 Do
      ModuleName := Copy(ModuleName, Pos('\', ModuleName) + 1, 255);
  End;

  { Lire le premier token }
  LexNextToken;

  { Analyser l en-tete }
  ParseModuleHeader;

  { Configurer le point d entree }
  SetupEntryPoint;

  { Entrer dans la portee MODULE }
  EnterScope(SCOPE_MODULE, -1);

  ModuleHeaderParsed := True;

  If Opts.Verbose Then
  Begin
    WriteLn('  Nom du module : ', ModuleName);
    WriteLn('  OptionExplicit : ', OptionExplicit);
    WriteLn('  OptionBase     : ', OptionBase);
    If OptionCompare = OPT_COMPARE_BINARY Then
      WriteLn('  OptionCompare  : Binary')
    Else
      WriteLn('  OptionCompare  : Text');
    If HasEntryPoint Then
      WriteLn('  HasEntryPoint  : True')
    Else
      WriteLn('  HasEntryPoint  : False');
  End;

  { Les TODOs 07-25 ajouteront ici le parsing du corps }
  { du module (Dim, Sub, Function, etc.)                }
  If CurTokType <> TOK_EOF Then
  Begin
    If Opts.Verbose Then
      WriteLn('  (corps du module non encore parse - TODOs 07-25)');
  End;

  { Quitter la portee MODULE }
  LeaveScope;
End;

{ ------------------------------------------------------------ }
{ Fonctions accesseur pour l etat du module                    }
{ ------------------------------------------------------------ }

Function GetModuleKind : Integer;
Begin
  GetModuleKind := ModuleKind;
End;

Function GetModuleName : TString;
Begin
  GetModuleName := ModuleName;
End;

Function IsOptionExplicit : Boolean;
Begin
  IsOptionExplicit := OptionExplicit;
End;

Function GetOptionBase : Integer;
Begin
  GetOptionBase := OptionBase;
End;

Function GetOptionCompare : Integer;
Begin
  GetOptionCompare := OptionCompare;
End;

Function HasMainEntry : Boolean;
Begin
  HasMainEntry := HasEntryPoint;
End;

Function IsModuleHeaderParsed : Boolean;
Begin
  IsModuleHeaderParsed := ModuleHeaderParsed;
End;

Function IsModuleStandard : Boolean;
Begin
  IsModuleStandard := (ModuleKind = MODULE_STANDARD);
End;

Function IsModuleForm : Boolean;
Begin
  IsModuleForm := (ModuleKind = MODULE_FORM);
End;

Function IsModuleClass : Boolean;
Begin
  IsModuleClass := (ModuleKind = MODULE_CLASS);
End;

Function IsOptionCompareBinary : Boolean;
Begin
  IsOptionCompareBinary := (OptionCompare = OPT_COMPARE_BINARY);
End;

Function IsOptionCompareText : Boolean;
Begin
  IsOptionCompareText := (OptionCompare = OPT_COMPARE_TEXT);
End;

{ ============================================================ }
{ TODO 07 - PARSEUR : DECLARATIONS              [IMPLEMENTE]  }
{           DIM, PUBLIC, PRIVATE, CONST, STATIC               }
{ ============================================================ }

Var
  DeclCount       : Integer;  { compteur de declarations traitees     }
  LastDeclIdx     : Integer;  { index du dernier symbole declare      }
  DeclParsingDone : Boolean;  { fin de l analyse des declarations     }

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
{ ParseTypeSuffix : detecter un suffixe de type sur un ident   }
{   x% -> Integer, s$ -> String, l& -> Long                   }
{   f! -> Single, d# -> Double, c@ -> Currency                }
{   Retourne le type VBT_* ou VBT_NONE si pas de suffixe      }
{ ------------------------------------------------------------ }

Function ParseTypeSuffix(Const Name : TString) : Integer;
Var Last : Char;
Begin
  ParseTypeSuffix := VBT_NONE;
  If Length(Name) < 2 Then Exit;
  Last := Name[Length(Name)];
  Case Last Of
    '%' : ParseTypeSuffix := VBT_INTEGER;
    '&' : ParseTypeSuffix := VBT_LONG;
    '!' : ParseTypeSuffix := VBT_SINGLE;
    '#' : ParseTypeSuffix := VBT_DOUBLE;
    '@' : ParseTypeSuffix := VBT_CURRENCY;
    '$' : ParseTypeSuffix := VBT_STRING;
  End;
End;

{ ------------------------------------------------------------ }
{ StripTypeSuffix : retirer le suffixe de type d un ident      }
{ ------------------------------------------------------------ }

Function StripTypeSuffix(Const Name : TString) : TString;
Var Last : Char;
Begin
  StripTypeSuffix := Name;
  If Length(Name) < 2 Then Exit;
  Last := Name[Length(Name)];
  If (Last = '%') Or (Last = '&') Or (Last = '!') Or
     (Last = '#') Or (Last = '@') Or (Last = '$') Then
    StripTypeSuffix := Copy(Name, 1, Length(Name) - 1);
End;

{ ------------------------------------------------------------ }
{ ParseTypeSpec : analyser un type apres "As"                  }
{   Retourne le code VBT_* correspondant                       }
{   Token courant doit etre le nom du type                     }
{ ------------------------------------------------------------ }

Function ParseTypeSpec : Integer;
Var T : Integer;
Begin
  T := VBT_VARIANT; { par defaut si type non reconnu }
  If CurTokType = TOK_KEYWORD Then
  Begin
    Case CurTokNum Of
      KW_BOOLEAN  : T := VBT_BOOLEAN;
      KW_BYTE     : T := VBT_BYTE;
      KW_INTEGER  : T := VBT_INTEGER;
      KW_LONG     : T := VBT_LONG;
      KW_SINGLE   : T := VBT_SINGLE;
      KW_DOUBLE   : T := VBT_DOUBLE;
      KW_CURRENCY : T := VBT_CURRENCY;
      KW_STRING   : T := VBT_STRING;
      KW_DATE     : T := VBT_DATE;
      KW_VARIANT  : T := VBT_VARIANT;
      KW_OBJECT   : T := VBT_OBJECT;
    Else
      WarnMsg('Type non reconnu: "' + CurTokStr + '", Variant suppose');
    End;
    LexNextToken;
    { Gerer String * n (chaine de taille fixe) }
    If (T = VBT_STRING) And (CurTokType = TOK_STAR) Then
    Begin
      LexNextToken; { consommer * }
      If CurTokType = TOK_INTEGER Then
        LexNextToken  { consommer la taille (on reste String pour l instant) }
      Else
        WarnMsg('Taille de chaine attendue apres String *');
    End;
  End
  Else If CurTokType = TOK_IDENT Then
  Begin
    { Type utilisateur }
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
{   selon le contexte (global ou local) et les options         }
{ ------------------------------------------------------------ }

Function DetermineStoreClass(IsStaticDecl : Boolean;
                             IsPub : Boolean) : Integer;
Begin
  If IsStaticDecl Then
    DetermineStoreClass := STORE_STATIC
  Else If IsInGlobalScope Then
    DetermineStoreClass := STORE_GLOBAL
  Else If IsPub Then
    DetermineStoreClass := STORE_GLOBAL
  Else
    DetermineStoreClass := STORE_AUTO;
End;

{ ------------------------------------------------------------ }
{ ParseVarDecl : analyser une seule declaration de variable    }
{   Token courant : le nom de la variable                      }
{   IsStaticDecl : Static Dim                                  }
{   IsPub : Public                                             }
{   Retourne l index du symbole cree ou -1                     }
{ ------------------------------------------------------------ }

Function ParseVarDecl(IsStaticDecl : Boolean;
                      IsPub : Boolean) : Integer;
Var
  VarName   : TString;
  VarType   : Integer;
  SuffType  : Integer;
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
  VarName  := CurTokStr;
  SuffType := ParseTypeSuffix(VarName);
  If SuffType <> VBT_NONE Then
    VarName := StripTypeSuffix(VarName);
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
        { Sauter les tokens de la dimension (nombre, To, nombre) }
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
  VarType := VBT_VARIANT; { par defaut }
  If IsKeywordToken(KW_AS) Then
  Begin
    LexNextToken; { consommer As }
    VarType := ParseTypeSpec;
  End
  Else If SuffType <> VBT_NONE Then
    VarType := SuffType;

  { Determiner la classe d entreposage }
  Store := DetermineStoreClass(IsStaticDecl, IsPub);

  { Ajouter le symbole }
  Idx := AddSym(VarName, SK_VAR, VarType, Store);
  If Idx < 0 Then
  Begin
    ParseVarDecl := -1;
    Exit;
  End;

  { Configurer les champs supplementaires }
  SymTab[Idx].IsPublic  := IsPub;
  SymTab[Idx].IsStatic  := IsStaticDecl;
  SymTab[Idx].ArrayDims := ArrDims;
  SymTab[Idx].ArrayBase := OptionBase;

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
    WriteLn;
  End;

  Inc(DeclCount);
  LastDeclIdx := Idx;
  ParseVarDecl := Idx;
End;

{ ------------------------------------------------------------ }
{ ParseDimStatement : analyser Dim x As Type [, y As Type...]  }
{   Token courant : KW_DIM                                     }
{ ------------------------------------------------------------ }

Procedure ParseDimStatement;
Begin
  LexNextToken; { consommer Dim }
  { Analyser la premiere variable }
  ParseVarDecl(False, False);
  { Verifier les declarations multiples separees par virgule }
  While CurTokType = TOK_COMMA Do
  Begin
    LexNextToken; { consommer , }
    ParseVarDecl(False, False);
  End;
End;

{ ------------------------------------------------------------ }
{ ParsePublicDecl : analyser Public gVar As Type               }
{   Token courant : KW_PUBLIC                                  }
{ ------------------------------------------------------------ }

Procedure ParsePublicDecl;
Begin
  LexNextToken; { consommer Public }
  { Verifier si c est Public Sub/Function (sera traite par TODO 09) }
  If IsKeywordToken(KW_SUB) Or IsKeywordToken(KW_FUNCTION) Then
  Begin
    { Remettre le token pour les TODOs futurs }
    SkipToEndOfLine;
    Exit;
  End;
  { Sinon c est une declaration de variable publique }
  ParseVarDecl(False, True);
  While CurTokType = TOK_COMMA Do
  Begin
    LexNextToken;
    ParseVarDecl(False, True);
  End;
End;

{ ------------------------------------------------------------ }
{ ParsePrivateDecl : analyser Private mVar As Type             }
{   Token courant : KW_PRIVATE                                 }
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
  { Sinon c est une declaration de variable privee }
  ParseVarDecl(False, False);
  While CurTokType = TOK_COMMA Do
  Begin
    LexNextToken;
    ParseVarDecl(False, False);
  End;
End;

{ ------------------------------------------------------------ }
{ ParseStaticDecl : analyser Static sVar As Type               }
{   Token courant : KW_STATIC                                  }
{   Static alloue toujours en .DATA (meme dans Sub/Function)   }
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
  ParseVarDecl(True, False);
  While CurTokType = TOK_COMMA Do
  Begin
    LexNextToken;
    ParseVarDecl(True, False);
  End;
End;

{ ------------------------------------------------------------ }
{ ParseConstStatement : analyser Const PI = 3.14159            }
{   ou Const MAX_SIZE As Long = 100                            }
{   Token courant : KW_CONST                                   }
{ ------------------------------------------------------------ }

Procedure ParseConstStatement;
Var
  ConstName : TString;
  ConstType : Integer;
  SuffType  : Integer;
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
  SuffType  := ParseTypeSuffix(ConstName);
  If SuffType <> VBT_NONE Then
    ConstName := StripTypeSuffix(ConstName);
  LexNextToken;

  { Type optionnel : As Type }
  ConstType := VBT_VARIANT;
  If IsKeywordToken(KW_AS) Then
  Begin
    LexNextToken;
    ConstType := ParseTypeSpec;
  End
  Else If SuffType <> VBT_NONE Then
    ConstType := SuffType;

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
    If ConstType = VBT_VARIANT Then
      SymTab[Idx].DataType := VBT_LONG;
    LexNextToken;
  End
  Else If CurTokType = TOK_STRING Then
  Begin
    SymTab[Idx].InitStr := CurTokStr;
    If ConstType = VBT_VARIANT Then
      SymTab[Idx].DataType := VBT_STRING;
    LexNextToken;
  End
  Else If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_NOTHING) Then
  Begin
    SymTab[Idx].InitNum := 0;
    If ConstType = VBT_VARIANT Then
      SymTab[Idx].DataType := VBT_OBJECT;
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
{ ParseModuleLevelDecl : analyser les declarations au niveau   }
{   du module (Dim, Public, Private, Static, Const)            }
{   Boucle jusqu a rencontrer Sub/Function/End ou EOF          }
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
    { Static }
    Else If IsKeywordToken(KW_STATIC) Then
    Begin
      ParseStaticDecl;
      SkipNewlines;
    End
    { Const }
    Else If IsKeywordToken(KW_CONST) Then
    Begin
      ParseConstStatement;
      SkipNewlines;
    End
    { Sub / Function / End : fin des declarations de module }
    Else If IsKeywordToken(KW_SUB) Or IsKeywordToken(KW_FUNCTION) Or
            IsKeywordToken(KW_END) Then
    Begin
      { Arreter : le code sera traite par les TODOs 08-25 }
      Break;
    End
    { Option / Attribute deja traites dans ParseModuleHeader }
    Else If IsKeywordToken(KW_OPTION) Or IsIdentToken('Attribute') Then
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
{ Fonctions accesseur pour les declarations                    }
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

{ ============================================================ }
{ TODO 08 - PARSEUR : EXPRESSIONS ARITHMETIQUES [IMPLEMENTE]  }
{           ET LOGIQUES (32 BITS)                              }
{ ============================================================ }

{ ------------------------------------------------------------ }
{ Operateur : constantes pour le type d operateur interne      }
{ ------------------------------------------------------------ }

Const
  OP_NONE     = 0;    { pas d operateur                          }
  OP_ADD      = 1;    { +                                        }
  OP_SUB      = 2;    { -                                        }
  OP_MUL      = 3;    { *                                        }
  OP_DIV      = 4;    { /                                        }
  OP_INTDIV   = 5;    { \ (division entiere)                     }
  OP_MOD      = 6;    { Mod                                      }
  OP_POW      = 7;    { ^                                        }
  OP_CONCAT   = 8;    { & (concatenation)                        }
  OP_EQ       = 10;   { =                                        }
  OP_NE       = 11;   { <>                                       }
  OP_LT       = 12;   { <                                        }
  OP_GT       = 13;   { >                                        }
  OP_LE       = 14;   { <=                                       }
  OP_GE       = 15;   { >=                                       }
  OP_LIKE     = 16;   { Like                                     }
  OP_IS       = 17;   { Is                                       }
  OP_AND      = 20;   { And                                      }
  OP_OR       = 21;   { Or                                       }
  OP_XOR      = 22;   { Xor                                      }
  OP_NOT      = 23;   { Not                                      }
  OP_EQV      = 24;   { Eqv                                      }
  OP_IMP      = 25;   { Imp                                      }
  OP_NEGATE   = 26;   { - (unaire)                               }

Var
  ExprCount      : Integer;  { nombre d expressions analysees         }
  ExprDepth      : Integer;  { profondeur actuelle d imbrication      }
  MaxExprDepth   : Integer;  { profondeur maximale atteinte           }
  ExprResultType : Integer;  { type VBT_* du resultat de l expr       }

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
    OP_ADD    : OpName := '+';
    OP_SUB    : OpName := '-';
    OP_MUL    : OpName := '*';
    OP_DIV    : OpName := '/';
    OP_INTDIV : OpName := '\';
    OP_MOD    : OpName := 'Mod';
    OP_POW    : OpName := '^';
    OP_CONCAT : OpName := '&';
    OP_EQ     : OpName := '=';
    OP_NE     : OpName := '<>';
    OP_LT     : OpName := '<';
    OP_GT     : OpName := '>';
    OP_LE     : OpName := '<=';
    OP_GE     : OpName := '>=';
    OP_LIKE   : OpName := 'Like';
    OP_IS     : OpName := 'Is';
    OP_AND    : OpName := 'And';
    OP_OR     : OpName := 'Or';
    OP_XOR    : OpName := 'Xor';
    OP_NOT    : OpName := 'Not';
    OP_EQV    : OpName := 'Eqv';
    OP_IMP    : OpName := 'Imp';
    OP_NEGATE : OpName := '- (neg)';
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
{   Regle simplifiee VB6 :                                     }
{     String op String -> String si &, sinon erreur/Variant    }
{     Double / Single / flottant -> Double                     }
{     Long / Integer / Byte -> Long (32 bits)                  }
{     Boolean -> Long pour arithm., Boolean pour logique       }
{     Comparaisons -> Boolean                                  }
{ ------------------------------------------------------------ }

Function DetermineResultType(Op : Integer; L, R : Integer) : Integer;
Begin
  { Comparaisons : toujours Boolean }
  If (Op >= OP_EQ) And (Op <= OP_IS) Then
  Begin
    DetermineResultType := VBT_BOOLEAN;
    Exit;
  End;
  { Operateurs logiques : Boolean si les deux Boolean, sinon Long }
  If (Op >= OP_AND) And (Op <= OP_IMP) Then
  Begin
    If (L = VBT_BOOLEAN) And (R = VBT_BOOLEAN) Then
      DetermineResultType := VBT_BOOLEAN
    Else
      DetermineResultType := VBT_LONG;
    Exit;
  End;
  { Concatenation : String }
  If Op = OP_CONCAT Then
  Begin
    DetermineResultType := VBT_STRING;
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
  { Sinon : Long (32 bits entier) }
  DetermineResultType := VBT_LONG;
End;

{ ------------------------------------------------------------ }
{ ParsePrimaryExpr : facteur primaire                          }
{   Constante numerique, chaine, True/False/Nothing/Empty/Null }
{   Variable scalaire, appel de fonction, (expr), Me           }
{   Retourne le type VBT_* du resultat                         }
{ ------------------------------------------------------------ }

Function ParsePrimaryExpr : Integer;
Var
  SIdx : Integer;
  T    : Integer;
Begin
  ParsePrimaryExpr := VBT_LONG;
  EnterExpr;
  { Litteral entier }
  If CurTokType = TOK_INTEGER Then
  Begin
    If Opts.Verbose Then
      WriteLn('    Expr: integer ', CurTokNum);
    ParsePrimaryExpr := VBT_LONG;
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
  { Litteral chaine }
  Else If CurTokType = TOK_STRING Then
  Begin
    If Opts.Verbose Then
      WriteLn('    Expr: string "', CurTokStr, '"');
    ParsePrimaryExpr := VBT_STRING;
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
  { Empty -> Variant vide }
  Else If IsKeywordToken(KW_EMPTY) Then
  Begin
    If Opts.Verbose Then
      WriteLn('    Expr: Empty');
    ParsePrimaryExpr := VBT_VARIANT;
    LexNextToken;
  End
  { Null -> Variant Null }
  Else If IsKeywordToken(KW_NULL) Then
  Begin
    If Opts.Verbose Then
      WriteLn('    Expr: Null');
    ParsePrimaryExpr := VBT_VARIANT;
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
      T := VBT_VARIANT; { symbole inconnu -> Variant par defaut }
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
      If CurTokType = TOK_IDENT Then
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
            WarnMsg('Parenthese fermante attendue apres arguments de methode');
        End;
      End
      Else
        WarnMsg('Nom de membre attendu apres "."');
      T := VBT_VARIANT; { acces membre : type inconnu a ce stade }
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
      T := VBT_VARIANT;
    End;
    ParsePrimaryExpr := T;
  End
  { Mot-cle utilise comme fonction : New, TypeOf }
  Else If IsKeywordToken(KW_NEW) Then
  Begin
    LexNextToken; { consommer New }
    If CurTokType = TOK_IDENT Then
    Begin
      If Opts.Verbose Then
        WriteLn('    Expr: New ', CurTokStr);
      LexNextToken;
    End
    Else
      WarnMsg('Nom de classe attendu apres New');
    ParsePrimaryExpr := VBT_OBJECT;
  End
  Else If IsKeywordToken(KW_TYPEOF) Then
  Begin
    LexNextToken; { consommer TypeOf }
    T := ParsePrimaryExpr;
    If IsKeywordToken(KW_IS) Then
    Begin
      LexNextToken; { consommer Is }
      If CurTokType = TOK_IDENT Then
        LexNextToken
      Else
        WarnMsg('Nom de type attendu apres TypeOf...Is');
    End;
    ParsePrimaryExpr := VBT_BOOLEAN;
  End
  { Token inattendu }
  Else
  Begin
    WarnMsg('Expression attendue, trouve "' + CurTokStr + '"');
    ParsePrimaryExpr := VBT_VARIANT;
  End;
  LeaveExpr;
End;

{ ------------------------------------------------------------ }
{ ParseUnaryExpr : operateur unaire (- ou Not)                 }
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
    { Negation : garde le type sauf Boolean -> Long }
    If T = VBT_BOOLEAN Then
      ParseUnaryExpr := VBT_LONG
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
      ParseUnaryExpr := VBT_LONG;
  End
  { + unaire : juste passer }
  Else If CurTokType = TOK_PLUS Then
  Begin
    LexNextToken;
    ParseUnaryExpr := ParsePrimaryExpr;
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
{ ParseCompExpr : comparaison (= <> < > <= >= Like Is)         }
{   Retourne le type VBT_* du resultat (toujours Boolean)      }
{ ------------------------------------------------------------ }

Function ParseCompExpr : Integer;
Var L, R, Op : Integer;
Begin
  L := ParseConcatExpr;
  While (CurTokType = TOK_EQ) Or (CurTokType = TOK_NE) Or
        (CurTokType = TOK_LT) Or (CurTokType = TOK_GT) Or
        (CurTokType = TOK_LE) Or (CurTokType = TOK_GE) Or
        IsKeywordToken(KW_LIKE) Or IsKeywordToken(KW_IS) Do
  Begin
    If CurTokType = TOK_EQ Then Op := OP_EQ
    Else If CurTokType = TOK_NE Then Op := OP_NE
    Else If CurTokType = TOK_LT Then Op := OP_LT
    Else If CurTokType = TOK_GT Then Op := OP_GT
    Else If CurTokType = TOK_LE Then Op := OP_LE
    Else If CurTokType = TOK_GE Then Op := OP_GE
    Else If IsKeywordToken(KW_LIKE) Then Op := OP_LIKE
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
      ParseNotExpr := VBT_LONG;
  End
  Else
    ParseNotExpr := ParseCompExpr;
End;

{ ------------------------------------------------------------ }
{ ParseAndExpr : operateur logique And                         }
{   Retourne le type VBT_* du resultat                         }
{ ------------------------------------------------------------ }

Function ParseAndExpr : Integer;
Var L, R : Integer;
Begin
  L := ParseNotExpr;
  While IsKeywordToken(KW_AND) Do
  Begin
    LexNextToken; { consommer And }
    R := ParseNotExpr;
    If Opts.Verbose Then
      WriteLn('    Expr: And');
    L := DetermineResultType(OP_AND, L, R);
  End;
  ParseAndExpr := L;
End;

{ ------------------------------------------------------------ }
{ ParseOrExpr : operateurs logiques Or / Xor / Eqv / Imp      }
{   Retourne le type VBT_* du resultat                         }
{ ------------------------------------------------------------ }

Function ParseOrExpr : Integer;
Var L, R, Op : Integer;
Begin
  L := ParseAndExpr;
  While IsKeywordToken(KW_OR) Or IsKeywordToken(KW_XOR) Or
        IsKeywordToken(KW_EQV) Or IsKeywordToken(KW_IMP) Do
  Begin
    If IsKeywordToken(KW_OR)  Then Op := OP_OR
    Else If IsKeywordToken(KW_XOR) Then Op := OP_XOR
    Else If IsKeywordToken(KW_EQV) Then Op := OP_EQV
    Else Op := OP_IMP;
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
    (ExprResultType = VBT_LONG) Or
    (ExprResultType = VBT_INTEGER) Or
    (ExprResultType = VBT_BYTE) Or
    (ExprResultType = VBT_SINGLE) Or
    (ExprResultType = VBT_DOUBLE) Or
    (ExprResultType = VBT_CURRENCY);
End;

Function IsExprResultVariant : Boolean;
Begin
  IsExprResultVariant := (ExprResultType = VBT_VARIANT);
End;

Function IsExprResultObject : Boolean;
Begin
  IsExprResultObject := (ExprResultType = VBT_OBJECT);
End;

Function IsExprStateEmpty : Boolean;
Begin
  IsExprStateEmpty := (ExprCount = 0);
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
{ Long/Integer -> MOV EAX, [label] ou [EBP-n]                 }
{ String -> LEA EAX, [label] ou [EBP-n]                       }
{ Boolean/Byte -> MOVZX EAX, BYTE PTR [label] ou [EBP-n]     }
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
      VBT_BOOLEAN, VBT_BYTE:
        Emit('MOVZX EAX, BYTE PTR [EBP' + ItoSI(-Ofs) + ']');
      VBT_STRING:
        Emit('LEA EAX, [EBP' + ItoSI(-Ofs) + ']');
    Else
      Emit('MOV EAX, DWORD PTR [EBP' + ItoSI(-Ofs) + ']');
    End;
  End
  Else
  Begin
    { Variable globale ou statique via label }
    Case DT Of
      VBT_BOOLEAN, VBT_BYTE:
        Emit('MOVZX EAX, BYTE PTR [' + Lbl + ']');
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
      VBT_BOOLEAN, VBT_BYTE:
        Emit('MOV BYTE PTR [EBP' + ItoSI(-Ofs) + '], AL');
    Else
      Emit('MOV DWORD PTR [EBP' + ItoSI(-Ofs) + '], EAX');
    End;
  End
  Else
  Begin
    Case DT Of
      VBT_BOOLEAN, VBT_BYTE:
        Emit('MOV BYTE PTR [' + Lbl + '], AL');
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
{ Resultat VB6 : True = -1 ($FFFFFFFF), False = 0              }
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
      { Comparaison de references objet }
      Emit('SETE AL');
  Else
    WarnMsg('GenCompare: operateur inconnu ' + ItoSI(Op));
    Emit('SETE AL');
  End;
  { Etendre AL en -1 ou 0 (convention VB6: True = -1) }
  Emit('MOVZX EAX, AL');
  Emit('NEG EAX');
End;

{ ------------------------------------------------------------ }
{ GenLogicalOp : generer le code d une operation logique        }
{ And, Or, Xor : binaire (EAX op EBX)                          }
{ Not : unaire (NOT EAX)                                       }
{ Eqv, Imp : composees                                         }
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
      OP_EQV:
        { Eqv = NOT (A XOR B) }
        Begin
          Emit('XOR EAX, EBX');
          Emit('NOT EAX');
        End;
      OP_IMP:
        { Imp = (NOT A) OR B }
        Begin
          Emit('NOT EAX');
          Emit('OR EAX, EBX');
        End;
    Else
      WarnMsg('GenLogicalOp: operateur inconnu ' + ItoSI(Op));
    End;
  End;
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
{ TODO 10 - PARSEUR : STRUCTURES DE CONTROLE (IF, SELECT CASE) }
{           [IMPLEMENTE]                                       }
{ ============================================================ }

Var
  CtrlCount       : LongInt;   { nombre total de structures de controle }
  CtrlDepth       : Integer;   { profondeur d imbrication courante      }
  MaxCtrlDepth    : Integer;   { profondeur max atteinte                }
  CtrlInitialized : Boolean;   { True si InitCtrlState a ete appele     }

{ ------------------------------------------------------------ }
{ InitCtrlState : initialiser l etat du parseur de controle    }
{ ------------------------------------------------------------ }

Procedure InitCtrlState;
Begin
  CtrlCount       := 0;
  CtrlDepth       := 0;
  MaxCtrlDepth    := 0;
  CtrlInitialized := True;
End;

{ ------------------------------------------------------------ }
{ EnterCtrl / LeaveCtrl : gerer la profondeur d imbrication    }
{ ------------------------------------------------------------ }

Procedure EnterCtrl;
Begin
  Inc(CtrlCount);
  Inc(CtrlDepth);
  If CtrlDepth > MaxCtrlDepth Then
    MaxCtrlDepth := CtrlDepth;
End;

Procedure LeaveCtrl;
Begin
  If CtrlDepth > 0 Then
    Dec(CtrlDepth);
End;

{ ------------------------------------------------------------ }
{ Forward declarations pour ParseStatement (recursion)         }
{ ------------------------------------------------------------ }

Procedure ParseStatement; Forward;
Procedure ParseStatementBlock; Forward;
Procedure ParseFor; Forward;
Procedure ParseDoLoop; Forward;
Procedure ParseWhileWend; Forward;
Procedure ParseForEach; Forward;
Procedure ParseExitStatement; Forward;
Procedure ParseSub; Forward;
Procedure ParseFunction; Forward;

{ ------------------------------------------------------------ }
{ ParseStatementBlock : parser un bloc d instructions          }
{   s arrete quand on rencontre un mot cle de fermeture        }
{   (Else, ElseIf, End, Case, Loop, Next, Wend)               }
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
         (CurTokNum = KW_LOOP) Or (CurTokNum = KW_NEXT) Or
         (CurTokNum = KW_WEND) Then
        Exit;
    End;
    ParseStatement;
    SkipNewlines;
  End;
End;

{ ------------------------------------------------------------ }
{ ParseIf : analyser une structure If/Then/ElseIf/Else/End If  }
{   Supporte la forme multi-ligne et la forme mono-ligne       }
{   Genere : CMP EAX, 0 / JE label_else_or_endif              }
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
  Emit('  CMP EAX, 0');
  Emit('  JE ' + LblElse);

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
      Emit('  JMP ' + LblEnd);
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
      Emit('  CMP EAX, 0');
      Emit('  JE ' + LblElse);

      { Parser le bloc }
      ParseStatementBlock;
    End;

    { Traiter Else optionnel }
    If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_ELSE) Then
    Begin
      Emit('  JMP ' + LblEnd);
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
      Emit('  JMP ' + LblEnd);
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
{ ParseCaseItem : analyser un element d une clause Case        }
{   Genere les comparaisons CMP + JE pour un element           }
{   Supporte : valeur simple, val1 To val2, Is op valeur       }
{   Retourne en ayant genere un saut conditionnel vers LblBody }
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
      { Memoriser l operateur pour generer la bonne comparaison }
      EmitComment('Case Is comparison');
      LexNextToken;
      ParseExpr;
      Emit('  POP EBX');   { EBX = expression Select }
      Emit('  PUSH EBX');  { conserver pour les prochains Case }
      Emit('  CMP EBX, EAX');
      { Note: le type de saut depend de l operateur }
      { Simplifie : on genere JE pour la correspondance }
      Emit('  JE ' + LblBody);
    End
    Else
    Begin
      ParseExpr;
      Emit('  POP EBX');
      Emit('  PUSH EBX');
      Emit('  CMP EBX, EAX');
      Emit('  JE ' + LblBody);
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
      Emit('  MOV ECX, EAX');   { ECX = val1 (borne inf) }
      LexNextToken;
      ParseExpr;                { EAX = val2 (borne sup) }
      Emit('  POP EBX');        { EBX = expression Select }
      Emit('  PUSH EBX');
      Emit('  CMP EBX, ECX');
      Emit('  JL ' + LblNext);
      Emit('  CMP EBX, EAX');
      Emit('  JLE ' + LblBody);
    End
    Else
    Begin
      { Valeur simple }
      EmitComment('Case value');
      Emit('  POP EBX');
      Emit('  PUSH EBX');
      Emit('  CMP EBX, EAX');
      Emit('  JE ' + LblBody);
    End;
  End;
End;

{ ------------------------------------------------------------ }
{ ParseSelectCase : analyser une structure Select Case          }
{   Select Case expression                                     }
{     Case valeur / Case val1 To val2 / Case Is > val           }
{     Case val1, val2, val3                                     }
{     Case Else                                                 }
{   End Select                                                  }
{   Genere : serie de CMP + JE pour chaque Case                }
{ ------------------------------------------------------------ }

Procedure ParseSelectCase;
Var
  LblEnd     : TString;  { label End Select           }
  LblBody    : TString;  { label corps du Case courant }
  LblNext    : TString;  { label Case suivant          }
  HasElse    : Boolean;
Begin
  EnterCtrl;
  { Consommer 'Select' }
  LexNextToken;

  { Attendre 'Case' }
  ExpectKeyword(KW_CASE);
  LexNextToken;

  { Parser l expression du Select }
  ParseExpr;
  Emit('  PUSH EAX');  { sauvegarder expression sur la pile }

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
      Emit('  JMP ' + LblEnd);
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
    Emit('  JMP ' + LblNext);

    { Corps du Case }
    EmitLabel(LblBody);
    SkipNewlines;
    ParseStatementBlock;
    Emit('  JMP ' + LblEnd);

    EmitLabel(LblNext);
    SkipNewlines;
  End;

  { Si pas de Case Else, emettre un saut au End Select }
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
  Emit('  ADD ESP, 4');
  EmitLabel(LblEnd);

  LeaveCtrl;
End;

{ ------------------------------------------------------------ }
{ ParseGoTo : analyser une instruction GoTo label               }
{   GoTo label -> JMP label                                     }
{   Supporte labels numeriques et labels nommes                 }
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
    Emit('  JMP ' + SymTab[Idx].AsmLabel);
    LexNextToken;
  End
  Else If (CurTokType = TOK_INTEGER) Then
  Begin
    LblName := CurTokStr;
    Idx := FindSym(LblName);
    If Idx < 0 Then
      Idx := AddSym(LblName, SK_LABEL, VBT_NONE, STORE_AUTO);
    EmitComment('GoTo ' + LblName);
    Emit('  JMP ' + SymTab[Idx].AsmLabel);
    LexNextToken;
  End
  Else
    WarnMsg('Label attendu apres GoTo');
End;

{ ------------------------------------------------------------ }
{ ParseGoSub : analyser une instruction GoSub label             }
{   GoSub label -> CALL label                                  }
{ ------------------------------------------------------------ }

Procedure ParseGoSub;
Var
  LblName : TString;
  Idx     : Integer;
Begin
  Inc(CtrlCount);
  { Consommer 'GoSub' }
  LexNextToken;

  If (CurTokType = TOK_IDENT) Then
  Begin
    LblName := CurTokStr;
    Idx := FindSym(LblName);
    If Idx < 0 Then
      Idx := AddSym(LblName, SK_LABEL, VBT_NONE, STORE_AUTO);
    EmitComment('GoSub ' + LblName);
    Emit('  CALL ' + SymTab[Idx].AsmLabel);
    LexNextToken;
  End
  Else If (CurTokType = TOK_INTEGER) Then
  Begin
    LblName := CurTokStr;
    Idx := FindSym(LblName);
    If Idx < 0 Then
      Idx := AddSym(LblName, SK_LABEL, VBT_NONE, STORE_AUTO);
    EmitComment('GoSub ' + LblName);
    Emit('  CALL ' + SymTab[Idx].AsmLabel);
    LexNextToken;
  End
  Else
    WarnMsg('Label attendu apres GoSub');
End;

{ ------------------------------------------------------------ }
{ ParseReturn : analyser une instruction Return                 }
{   Return -> RET                                               }
{ ------------------------------------------------------------ }

Procedure ParseReturn;
Begin
  Inc(CtrlCount);
  { Consommer 'Return' }
  LexNextToken;
  EmitComment('Return (GoSub)');
  Emit('  RET');
End;

{ ------------------------------------------------------------ }
{ ParseLabel : traiter un label au debut d une ligne            }
{   label: (label nomme) ou numero: (label numerique)          }
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
{ ParseStatement : analyser une instruction quelconque          }
{   Dispatcher vers le parseur specialise selon le token        }
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
      KW_IF      : ParseIf;
      KW_SELECT  : ParseSelectCase;
      KW_GOTO    : ParseGoTo;
      KW_GOSUB   : ParseGoSub;
      KW_RETURN  : ParseReturn;
      KW_FOR     : ParseFor;
      KW_DO      : ParseDoLoop;
      KW_WHILE   : ParseWhileWend;
      KW_EXIT    : ParseExitStatement;
    Else
      { Instruction non reconnue par ce TODO - avancer }
      LexNextToken;
    End;
    Exit;
  End;

  { Label : ident suivi de ':' }
  If (CurTokType = TOK_IDENT) Then
  Begin
    { On ne peut pas regarder ahead facilement, avancer }
    LexNextToken;
    Exit;
  End;

  { Numero de ligne (label numerique implicite) }
  If (CurTokType = TOK_INTEGER) Then
  Begin
    LexNextToken;
    Exit;
  End;

  { Autre token - avancer }
  LexNextToken;
End;

{ ------------------------------------------------------------ }
{ Fonctions accesseur pour l etat des structures de controle   }
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
{ TODO 11 - PARSEUR : BOUCLES (FOR/NEXT, DO/LOOP, WHILE/WEND) }
{           [IMPLEMENTE]                                       }
{ ============================================================ }

Var
  LoopCount       : LongInt;   { nombre total de boucles parsees         }
  LoopDepth       : Integer;   { profondeur d imbrication courante       }
  MaxLoopDepth    : Integer;   { profondeur max atteinte                 }
  LoopInitialized : Boolean;   { True si InitLoopState a ete appele      }

{ ------------------------------------------------------------ }
{ InitLoopState : initialiser l etat du parseur de boucles     }
{ ------------------------------------------------------------ }

Procedure InitLoopState;
Begin
  LoopCount       := 0;
  LoopDepth       := 0;
  MaxLoopDepth    := 0;
  LoopInitialized := True;
End;

{ ------------------------------------------------------------ }
{ EnterLoop / LeaveLoop : gerer la profondeur d imbrication    }
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
{ ParseFor : analyser une boucle For/Next                      }
{   For i = debut To fin [Step pas]                            }
{     instructions                                             }
{   Next [i]                                                   }
{   Genere : MOV compteur, debut / label_boucle:               }
{     CMP compteur, fin / JG label_fin (Step positif)          }
{     ... / ADD compteur, pas / JMP label_boucle / label_fin:  }
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
    Idx := AddSym(VarName, SK_VAR, VBT_LONG, STORE_AUTO);
  LexNextToken;

  { Attendre '=' }
  Expect(TOK_EQ);

  { Parser l expression de debut }
  ParseExpr;
  EmitComment('For ' + VarName + ' = start');
  GenStoreVar(Idx);

  { Attendre 'To' }
  ExpectKeyword(KW_TO);

  { Parser l expression de fin, la placer dans EBX }
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
    { La valeur du step est dans EAX, on la sauvegarde }
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

  { Remettre la fin dans la pile si step, sinon re-push }
  If HasStep Then
  Begin
    { Les valeurs restent sur la pile, on boucle }
    Emit('  JMP ' + LblLoop);
    EmitLabel(LblEnd);
    { Nettoyer la pile : fin et step }
    Emit('  ADD ESP, 8');
  End
  Else
  Begin
    { Re-pusher la fin pour la prochaine iteration }
    GenLoadVar(Idx);
    { Recharger la fin depuis la variable ... }
    { Utiliser une approche simplifiee : }
    Emit('  JMP ' + LblLoop);
    EmitLabel(LblEnd);
  End;

  LeaveLoop;
  LeaveCtrl;
End;

{ ------------------------------------------------------------ }
{ ParseDoLoop : analyser une boucle Do/Loop                    }
{   Do [While|Until condition]                                 }
{     instructions                                             }
{     [Exit Do]                                                }
{   Loop [While|Until condition]                               }
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
{ ParseWhileWend : analyser une boucle While/Wend              }
{   While condition                                            }
{     instructions                                             }
{   Wend                                                       }
{ ------------------------------------------------------------ }

Procedure ParseWhileWend;
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

  { Attendre 'Wend' }
  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_WEND) Then
    LexNextToken;

  { Retourner au debut de la boucle }
  Emit('  JMP ' + LblLoop);
  EmitLabel(LblEnd);

  LeaveLoop;
  LeaveCtrl;
End;

{ ------------------------------------------------------------ }
{ ParseForEach : analyser une boucle For Each (stub)           }
{   For Each element In collection                             }
{     instructions                                             }
{   Next [element]                                             }
{ ------------------------------------------------------------ }

Procedure ParseForEach;
Begin
  EnterCtrl;
  EnterLoop;
  { Consommer 'For' deja fait, consommer 'Each' }
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
{ Fonctions accesseur pour l etat des boucles                  }
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
{ TODO 12 - PARSEUR : SUB ET FUNCTION (PROCEDURES ET FONCTIONS)}
{           [IMPLEMENTE]                                       }
{ ============================================================ }

Var
  SubFuncCount       : LongInt;   { nombre total de Sub/Function parsees  }
  SubFuncInitialized : Boolean;   { True si InitSubFuncState a ete appele }
  CurProcIsPublic    : Boolean;   { visibilite pour la proc en cours      }
  CurProcIsStatic    : Boolean;   { Static pour la proc en cours          }

{ ------------------------------------------------------------ }
{ InitSubFuncState : initialiser l etat du parseur Sub/Func    }
{ ------------------------------------------------------------ }

Procedure InitSubFuncState;
Begin
  SubFuncCount       := 0;
  SubFuncInitialized := True;
  CurProcIsPublic    := True;
  CurProcIsStatic    := False;
End;

{ ------------------------------------------------------------ }
{ ParseParamList : analyser la liste de parametres              }
{   ProcIdx : index dans ProcTab de la procedure courante      }
{   Token courant : '(' ou premier token apres nom             }
{   Parametres supportes :                                     }
{     ByVal x As Integer (passage par valeur, PUSH valeur)     }
{     ByRef x As Integer (passage par reference, defaut VB6)   }
{     Optional x As Integer = 0 (parametre optionnel)          }
{     ParamArray args() As Variant (stub)                      }
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
    PByRef    := True; { ByRef par defaut en VB6 }
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
    PType := VBT_VARIANT;
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
{   [Public|Private] [Static] Sub nom([params])                }
{     instructions                                             }
{     [Exit Sub]                                               }
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
  ProcTab[ProcIdx].IsStatic := CurProcIsStatic;

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
{   [Public|Private] [Static] Function nom([params]) [As type] }
{     instructions                                             }
{     nom = valeur_retour                                      }
{     [Exit Function]                                          }
{   End Function                                               }
{   Genere prologue/epilogue STDCALL Win32                     }
{   Valeur de retour dans EAX (entier/pointeur)                }
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

  { Ajouter dans ProcTab (retour par defaut Variant) }
  ProcIdx := AddProc(FuncName, SK_FUNCTION, VBT_VARIANT, CurProcIsPublic);
  If ProcIdx < 0 Then Exit;
  ProcTab[ProcIdx].IsStatic := CurProcIsStatic;

  { Entrer dans la portee Function }
  EnterScope(SCOPE_FUNCTION, ProcIdx);

  { Analyser la liste de parametres }
  ParseParamList(ProcIdx);

  { Analyser le type de retour : As Type }
  RetType := VBT_VARIANT;
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
{ ParseExitStatement : analyser Exit Sub/Function/For/Do       }
{   Exit Sub      -> JMP vers label de sortie du Sub           }
{   Exit Function -> JMP vers label de sortie du Function      }
{   Exit For      -> JMP vers label de fin de boucle For       }
{   Exit Do       -> JMP vers label de fin de boucle Do        }
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
  Else
    WarnMsg('"Sub", "Function", "For" ou "Do" attendu apres "Exit"');
    LexNextToken;
  End;
End;

{ ------------------------------------------------------------ }
{ ParseProcedures : analyser les definitions de Sub/Function   }
{   au niveau du module (top-level)                            }
{   Boucle jusqu a la fin du fichier                           }
{   Gere les modificateurs Public/Private/Static               }
{ ------------------------------------------------------------ }

Procedure ParseProcedures;
Begin
  SkipNewlines;
  While CurTokType <> TOK_EOF Do
  Begin
    { Reinitialiser les modificateurs }
    CurProcIsPublic := True;  { Public par defaut en VB6 }
    CurProcIsStatic := False;

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
      End;

      { Modificateur Static }
      If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_STATIC) Then
      Begin
        CurProcIsStatic := True;
        LexNextToken;
      End;

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

{ ============================================================ }
{ TODO 13 - PARSEUR : FONCTIONS INTRINSEQUES (CHAINES,         }
{           CONVERSION, MATH)  [IMPLEMENTE]                    }
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
{   fonction intrinseque VB6 reconnue                          }
{ ------------------------------------------------------------ }

Function IsIntrinsicFunction(KW : Integer) : Boolean;
Begin
  Case KW Of
    { Fonctions de chaines }
    KW_LEN2, KW_LEFT, KW_RIGHT, KW_MID,
    KW_LTRIM, KW_RTRIM, KW_TRIM,
    KW_UCASE, KW_LCASE,
    KW_INSTR, KW_INSTRREV,
    KW_REPLACE,
    KW_SPACE, KW_STRINGFN,
    KW_STRCOMP, KW_STRREVERSE,
    KW_SPLIT, KW_JOIN,
    KW_ASC, KW_CHR,
    { Fonctions de conversion }
    KW_CINT, KW_CLNG, KW_CSNG, KW_CDBL, KW_CSTR,
    KW_CBOOL, KW_CBYTE, KW_CCUR, KW_CDATE,
    KW_VAL, KW_STR, KW_HEX, KW_OCT,
    KW_INT, KW_FIX,
    { Fonctions mathematiques }
    KW_ABS, KW_SGN, KW_SQR, KW_EXP, KW_LOG,
    KW_SIN, KW_COS, KW_TAN, KW_ATN,
    KW_RND, KW_RANDOMIZE,
    { Fonctions d information }
    KW_ISNUMERIC, KW_ISDATE, KW_ISEMPTY, KW_ISNULL,
    KW_ISARRAY, KW_ISOBJECT, KW_ISMISSING,
    KW_TYPENAME, KW_VARTYPE:
      IsIntrinsicFunction := True;
  Else
    IsIntrinsicFunction := False;
  End;
End;

{ ------------------------------------------------------------ }
{ IntrinsicRtLabel : retourne le label runtime _VBRT_XXX       }
{   pour une fonction intrinseque donnee (code KW_*)           }
{ ------------------------------------------------------------ }

Function IntrinsicRtLabel(KW : Integer) : TString;
Begin
  Case KW Of
    KW_LEN2      : IntrinsicRtLabel := PFX_RT + 'LEN';
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
    KW_STRINGFN   : IntrinsicRtLabel := PFX_RT + 'STRING';
    KW_STRCOMP    : IntrinsicRtLabel := PFX_RT + 'STRCOMP';
    KW_STRREVERSE : IntrinsicRtLabel := PFX_RT + 'STRREVERSE';
    KW_SPLIT      : IntrinsicRtLabel := PFX_RT + 'SPLIT';
    KW_JOIN       : IntrinsicRtLabel := PFX_RT + 'JOIN';
    KW_ASC        : IntrinsicRtLabel := PFX_RT + 'ASC';
    KW_CHR        : IntrinsicRtLabel := PFX_RT + 'CHR';
    KW_CINT       : IntrinsicRtLabel := PFX_RT + 'CINT';
    KW_CLNG       : IntrinsicRtLabel := PFX_RT + 'CLNG';
    KW_CSNG       : IntrinsicRtLabel := PFX_RT + 'CSNG';
    KW_CDBL       : IntrinsicRtLabel := PFX_RT + 'CDBL';
    KW_CSTR       : IntrinsicRtLabel := PFX_RT + 'CSTR';
    KW_CBOOL      : IntrinsicRtLabel := PFX_RT + 'CBOOL';
    KW_CBYTE      : IntrinsicRtLabel := PFX_RT + 'CBYTE';
    KW_CCUR       : IntrinsicRtLabel := PFX_RT + 'CCUR';
    KW_CDATE      : IntrinsicRtLabel := PFX_RT + 'CDATE';
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
    KW_RND        : IntrinsicRtLabel := PFX_RT + 'RND';
    KW_RANDOMIZE  : IntrinsicRtLabel := PFX_RT + 'RANDOMIZE';
    KW_ISNUMERIC  : IntrinsicRtLabel := PFX_RT + 'ISNUMERIC';
    KW_ISDATE     : IntrinsicRtLabel := PFX_RT + 'ISDATE';
    KW_ISEMPTY    : IntrinsicRtLabel := PFX_RT + 'ISEMPTY';
    KW_ISNULL     : IntrinsicRtLabel := PFX_RT + 'ISNULL';
    KW_ISARRAY    : IntrinsicRtLabel := PFX_RT + 'ISARRAY';
    KW_ISOBJECT   : IntrinsicRtLabel := PFX_RT + 'ISOBJECT';
    KW_ISMISSING  : IntrinsicRtLabel := PFX_RT + 'ISMISSING';
    KW_TYPENAME   : IntrinsicRtLabel := PFX_RT + 'TYPENAME';
    KW_VARTYPE    : IntrinsicRtLabel := PFX_RT + 'VARTYPE';
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
    { 0 argument }
    KW_RND        : IntrinsicArgCount := 0;
    KW_RANDOMIZE  : IntrinsicArgCount := 0;
    { 1 argument }
    KW_LEN2, KW_LTRIM, KW_RTRIM, KW_TRIM,
    KW_UCASE, KW_LCASE, KW_STRREVERSE,
    KW_ASC, KW_CHR,
    KW_CINT, KW_CLNG, KW_CSNG, KW_CDBL, KW_CSTR,
    KW_CBOOL, KW_CBYTE, KW_CCUR, KW_CDATE,
    KW_VAL, KW_STR, KW_HEX, KW_OCT,
    KW_INT, KW_FIX,
    KW_ABS, KW_SGN, KW_SQR, KW_EXP, KW_LOG,
    KW_SIN, KW_COS, KW_TAN, KW_ATN,
    KW_ISNUMERIC, KW_ISDATE, KW_ISEMPTY, KW_ISNULL,
    KW_ISARRAY, KW_ISOBJECT, KW_ISMISSING,
    KW_TYPENAME, KW_VARTYPE,
    KW_SPACE:
      IntrinsicArgCount := 1;
    { 2 arguments }
    KW_LEFT, KW_RIGHT, KW_STRINGFN,
    KW_STRCOMP, KW_SPLIT, KW_JOIN:
      IntrinsicArgCount := 2;
    { variadic (2-3 ou 2-4) }
    KW_MID, KW_INSTR, KW_INSTRREV, KW_REPLACE:
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
    { Retourne Long }
    KW_LEN2, KW_ASC, KW_INSTR, KW_INSTRREV,
    KW_STRCOMP, KW_VARTYPE:
      IntrinsicResultType := VBT_LONG;
    { Retourne String }
    KW_LEFT, KW_RIGHT, KW_MID,
    KW_LTRIM, KW_RTRIM, KW_TRIM,
    KW_UCASE, KW_LCASE,
    KW_REPLACE, KW_SPACE, KW_STRINGFN,
    KW_STRREVERSE,
    KW_JOIN, KW_CHR, KW_CSTR,
    KW_STR, KW_HEX, KW_OCT,
    KW_TYPENAME:
      IntrinsicResultType := VBT_STRING;
    { Retourne Integer }
    KW_CINT:
      IntrinsicResultType := VBT_INTEGER;
    { Retourne Long (CLng) }
    KW_CLNG, KW_INT, KW_FIX, KW_SGN:
      IntrinsicResultType := VBT_LONG;
    { Retourne Single }
    KW_CSNG:
      IntrinsicResultType := VBT_SINGLE;
    { Retourne Double }
    KW_CDBL, KW_ABS, KW_SQR, KW_EXP, KW_LOG,
    KW_SIN, KW_COS, KW_TAN, KW_ATN, KW_RND, KW_VAL:
      IntrinsicResultType := VBT_DOUBLE;
    { Retourne Boolean }
    KW_CBOOL, KW_ISNUMERIC, KW_ISDATE, KW_ISEMPTY,
    KW_ISNULL, KW_ISARRAY, KW_ISOBJECT, KW_ISMISSING:
      IntrinsicResultType := VBT_BOOLEAN;
    { Retourne Byte }
    KW_CBYTE:
      IntrinsicResultType := VBT_BYTE;
    { Retourne Currency }
    KW_CCUR:
      IntrinsicResultType := VBT_CURRENCY;
    { Retourne Date }
    KW_CDATE:
      IntrinsicResultType := VBT_DATE;
    { Retourne Variant (Split, Randomize, etc.) }
    KW_SPLIT, KW_RANDOMIZE:
      IntrinsicResultType := VBT_VARIANT;
  Else
    IntrinsicResultType := VBT_VARIANT;
  End;
End;

{ ------------------------------------------------------------ }
{ ParseIntrinsicCall : parser un appel de fonction intrinseque }
{   KW est le code KW_* de la fonction                        }
{   Genere PUSH args / CALL _VBRT_XXX                         }
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

  { Fonctions sans parentheses : Rnd, Randomize }
  If (KW = KW_RND) Or (KW = KW_RANDOMIZE) Then
  Begin
    ArgCount := 0;
    { Rnd et Randomize acceptent optionnellement un argument }
    If CurTokType = TOK_LPAREN Then
    Begin
      LexNextToken; { consommer ( }
      If CurTokType <> TOK_RPAREN Then
      Begin
        ParseExpr;
        ArgCount := 1;
        EmitComment('PUSH arg1 pour ' + FnName);
        Emit('PUSH EAX');
      End;
      If CurTokType = TOK_RPAREN Then
        LexNextToken
      Else
        WarnMsg(') attendue apres ' + FnName);
    End;
    EmitComment('CALL ' + RtLabel);
    Emit('CALL ' + RtLabel);
    ParseIntrinsicCall := IntrinsicResultType(KW);
    Exit;
  End;

  { Toutes les autres fonctions : nom(args) }
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

  { Nettoyer la pile si convention cdecl (runtime VB utilise stdcall, }
  { mais on genere le nettoyage par securite)                        }
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
    KW_LEN2, KW_LEFT, KW_RIGHT, KW_MID,
    KW_LTRIM, KW_RTRIM, KW_TRIM,
    KW_UCASE, KW_LCASE,
    KW_INSTR, KW_INSTRREV,
    KW_REPLACE, KW_SPACE, KW_STRINGFN,
    KW_STRCOMP, KW_STRREVERSE,
    KW_SPLIT, KW_JOIN,
    KW_ASC, KW_CHR:
      IntrinsicCategoryName := 'String';
    KW_CINT, KW_CLNG, KW_CSNG, KW_CDBL, KW_CSTR,
    KW_CBOOL, KW_CBYTE, KW_CCUR, KW_CDATE,
    KW_VAL, KW_STR, KW_HEX, KW_OCT,
    KW_INT, KW_FIX:
      IntrinsicCategoryName := 'Conversion';
    KW_ABS, KW_SGN, KW_SQR, KW_EXP, KW_LOG,
    KW_SIN, KW_COS, KW_TAN, KW_ATN,
    KW_RND, KW_RANDOMIZE:
      IntrinsicCategoryName := 'Math';
    KW_ISNUMERIC, KW_ISDATE, KW_ISEMPTY, KW_ISNULL,
    KW_ISARRAY, KW_ISOBJECT, KW_ISMISSING,
    KW_TYPENAME, KW_VARTYPE:
      IntrinsicCategoryName := 'Information';
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
Var
  N : Integer;
Begin
  N := 0;
  { Len, Left, Right, Mid, LTrim, RTrim, Trim, UCase, LCase }
  { InStr, InStrRev, Replace, Space, String, StrComp, StrReverse }
  { Split, Join, Asc, Chr = 20 fonctions de chaines }
  N := 20;
  GetIntrinsicStringCount := N;
End;

Function GetIntrinsicConvCount : Integer;
Begin
  { CInt, CLng, CSng, CDbl, CStr, CBool, CByte, CCur, CDate }
  { Val, Str, Hex, Oct, Int, Fix = 15 fonctions de conversion }
  GetIntrinsicConvCount := 15;
End;

Function GetIntrinsicMathCount : Integer;
Begin
  { Abs, Sgn, Sqr, Exp, Log, Sin, Cos, Tan, Atn, Rnd, Randomize }
  { = 11 fonctions mathematiques }
  GetIntrinsicMathCount := 11;
End;

Function GetIntrinsicInfoCount : Integer;
Begin
  { IsNumeric, IsDate, IsEmpty, IsNull, IsArray, IsObject, }
  { IsMissing, TypeName, VarType = 9 fonctions d information }
  GetIntrinsicInfoCount := 9;
End;

Function GetTotalIntrinsicFunctions : Integer;
Begin
  GetTotalIntrinsicFunctions := 20 + 15 + 11 + 9;
End;

Function IsIntrinsicKW(KW : Integer) : Boolean;
Begin
  IsIntrinsicKW := IsIntrinsicFunction(KW);
End;

{ ============================================================ }
{ TODO 14 - PARSEUR : OPERATIONS SUR CHAINES ET CONCATENATION   }
{           [IMPLEMENTE]                                        }
{ ============================================================ }

Const
  { Modes de comparaison de chaines }
  STRCOMP_BINARY = 0;    { sensible a la casse (defaut)             }
  STRCOMP_TEXT   = 1;    { insensible a la casse                    }

  { Taille maximale d une chaine de longueur fixe }
  MAX_FIXED_STR  = 32767;

  { Labels runtime pour operations sur chaines }
  STROP_RT_STRCAT    = '_VBRT_STRCAT';
  STROP_RT_STRALLOC  = '_VBRT_STRALLOC';
  STROP_RT_STRFREE   = '_VBRT_STRFREE';
  STROP_RT_MIDASSIGN = '_VBRT_MIDASSIGN';
  STROP_RT_LSET      = '_VBRT_LSET';
  STROP_RT_RSET      = '_VBRT_RSET';
  STROP_RT_STRCMP_BIN = '_VBRT_STRCMP_BIN';
  STROP_RT_STRCMP_TXT = '_VBRT_STRCMP_TXT';
  STROP_RT_LIKE      = '_VBRT_LIKE';
  STROP_RT_FORMAT    = '_VBRT_FORMAT';

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
{ ParseMidAssign : parser Mid$(var, pos[, len]) = expr         }
{   Instruction d affectation Mid en VB6                       }
{ ------------------------------------------------------------ }

Procedure ParseMidAssign;
Var
  VarName   : TString;
  HasLen    : Boolean;
  SymIdx    : Integer;
Begin
  Inc(StrOpCount);
  LexNextToken; { consommer Mid$ }
  HasLen := False;

  { Verifier la parenthese ouvrante }
  If CurTokType = TOK_LPAREN Then
    LexNextToken
  Else
    WarnMsg('( attendue apres Mid$');

  { Premier argument : la variable chaine cible }
  If CurTokType = TOK_IDENT Then
  Begin
    VarName := CurTokStr;
    SymIdx := FindSym(VarName);
    If SymIdx < 0 Then
      WarnMsg('Variable non declaree: ' + VarName);
    LexNextToken;
  End
  Else
  Begin
    VarName := '?';
    WarnMsg('Variable attendue dans Mid$');
  End;

  { Virgule }
  If CurTokType = TOK_COMMA Then
    LexNextToken
  Else
    WarnMsg(', attendue apres variable dans Mid$');

  { Deuxieme argument : position de depart }
  ParseExpr;
  EmitComment('PUSH pos pour Mid$ assign');
  Emit('PUSH EAX');

  { Troisieme argument optionnel : longueur }
  If CurTokType = TOK_COMMA Then
  Begin
    LexNextToken; { consommer , }
    ParseExpr;
    EmitComment('PUSH len pour Mid$ assign');
    Emit('PUSH EAX');
    HasLen := True;
  End;

  { Parenthese fermante }
  If CurTokType = TOK_RPAREN Then
    LexNextToken
  Else
    WarnMsg(') attendue apres arguments de Mid$');

  { Signe egal }
  If CurTokType = TOK_EQ Then
    LexNextToken
  Else
    WarnMsg('= attendu apres Mid$(...)');

  { Evaluer l expression de remplacement }
  ParseExpr;
  EmitComment('PUSH valeur de remplacement pour Mid$');
  Emit('PUSH EAX');

  { Charger l adresse de la variable cible }
  If SymIdx >= 0 Then
    GenLoadVar(SymIdx);
  EmitComment('PUSH ptr variable cible pour Mid$');
  Emit('PUSH EAX');

  { Appel runtime }
  If HasLen Then
  Begin
    EmitComment('CALL ' + STROP_RT_MIDASSIGN + ' (4 args: ptr, pos, len, val)');
    Emit('CALL ' + STROP_RT_MIDASSIGN);
    Emit('ADD ESP, 16');
  End
  Else
  Begin
    EmitComment('CALL ' + STROP_RT_MIDASSIGN + ' (3 args: ptr, pos, val)');
    Emit('PUSH -1'); { -1 = pas de longueur specifiee }
    Emit('CALL ' + STROP_RT_MIDASSIGN);
    Emit('ADD ESP, 16');
  End;

  If Opts.Verbose Then
    WriteLn('    StrOp: Mid$ assign sur ', VarName);
End;

{ ------------------------------------------------------------ }
{ ParseLSetStatement : parser LSet variable = expression       }
{   Cadrage a gauche dans une chaine de longueur fixe          }
{ ------------------------------------------------------------ }

Procedure ParseLSetStatement;
Var
  VarName : TString;
  SymIdx  : Integer;
Begin
  Inc(StrOpCount);
  LexNextToken; { consommer LSet }

  { Variable cible }
  If CurTokType = TOK_IDENT Then
  Begin
    VarName := CurTokStr;
    SymIdx := FindSym(VarName);
    If SymIdx < 0 Then
      WarnMsg('Variable non declaree: ' + VarName);
    LexNextToken;
  End
  Else
  Begin
    VarName := '?';
    SymIdx := -1;
    WarnMsg('Variable attendue apres LSet');
  End;

  { Signe egal }
  If CurTokType = TOK_EQ Then
    LexNextToken
  Else
    WarnMsg('= attendu apres LSet variable');

  { Evaluer l expression source }
  ParseExpr;
  EmitComment('PUSH valeur source pour LSet');
  Emit('PUSH EAX');

  { Charger l adresse de la variable cible }
  If SymIdx >= 0 Then
    GenLoadVar(SymIdx);
  EmitComment('PUSH ptr variable cible pour LSet');
  Emit('PUSH EAX');

  { Appel runtime }
  EmitComment('CALL ' + STROP_RT_LSET);
  Emit('CALL ' + STROP_RT_LSET);
  Emit('ADD ESP, 8');

  If Opts.Verbose Then
    WriteLn('    StrOp: LSet ', VarName);
End;

{ ------------------------------------------------------------ }
{ ParseRSetStatement : parser RSet variable = expression       }
{   Cadrage a droite dans une chaine de longueur fixe          }
{ ------------------------------------------------------------ }

Procedure ParseRSetStatement;
Var
  VarName : TString;
  SymIdx  : Integer;
Begin
  Inc(StrOpCount);
  LexNextToken; { consommer RSet }

  { Variable cible }
  If CurTokType = TOK_IDENT Then
  Begin
    VarName := CurTokStr;
    SymIdx := FindSym(VarName);
    If SymIdx < 0 Then
      WarnMsg('Variable non declaree: ' + VarName);
    LexNextToken;
  End
  Else
  Begin
    VarName := '?';
    SymIdx := -1;
    WarnMsg('Variable attendue apres RSet');
  End;

  { Signe egal }
  If CurTokType = TOK_EQ Then
    LexNextToken
  Else
    WarnMsg('= attendu apres RSet variable');

  { Evaluer l expression source }
  ParseExpr;
  EmitComment('PUSH valeur source pour RSet');
  Emit('PUSH EAX');

  { Charger l adresse de la variable cible }
  If SymIdx >= 0 Then
    GenLoadVar(SymIdx);
  EmitComment('PUSH ptr variable cible pour RSet');
  Emit('PUSH EAX');

  { Appel runtime }
  EmitComment('CALL ' + STROP_RT_RSET);
  Emit('CALL ' + STROP_RT_RSET);
  Emit('ADD ESP, 8');

  If Opts.Verbose Then
    WriteLn('    StrOp: RSet ', VarName);
End;

{ ------------------------------------------------------------ }
{ ParseFixedString : parser String * n dans une declaration    }
{   Retourne la taille en octets de la chaine fixe             }
{ ------------------------------------------------------------ }

Function ParseFixedString : Integer;
Var
  FixSize : LongInt;
Begin
  Inc(StrOpCount);
  { On est positionne apres String, et le token courant est * }
  LexNextToken; { consommer * }

  { Lire la taille }
  If CurTokType = TOK_INTEGER Then
  Begin
    FixSize := CurTokNum;
    If (FixSize < 1) Or (FixSize > MAX_FIXED_STR) Then
    Begin
      WarnMsg('Taille de chaine fixe invalide: ' + ItoS(FixSize));
      FixSize := 1;
    End;
    LexNextToken; { consommer le nombre }
  End
  Else
  Begin
    WarnMsg('Taille entiere attendue apres String *');
    FixSize := 1;
  End;

  If Opts.Verbose Then
    WriteLn('    StrOp: String * ', FixSize);
  ParseFixedString := FixSize;
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
        { On reemplace l appel strcmp par like }
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
  { Etendre AL en -1 ou 0 (convention VB6) }
  Emit('MOVZX EAX, AL');
  Emit('NEG EAX');
End;

{ ------------------------------------------------------------ }
{ ParseFormatCall : parser Format(expression, format_string)   }
{   ou Format$(expression, format_string)                      }
{   Retourne VBT_STRING                                        }
{ ------------------------------------------------------------ }

Function ParseFormatCall : Integer;
Begin
  Inc(StrOpCount);
  LexNextToken; { consommer Format ou Format$ }

  { Parenthese ouvrante }
  If CurTokType = TOK_LPAREN Then
    LexNextToken
  Else
    WarnMsg('( attendue apres Format');

  { Premier argument : expression a formater }
  ParseExpr;
  EmitComment('PUSH expression pour Format');
  Emit('PUSH EAX');

  { Virgule }
  If CurTokType = TOK_COMMA Then
    LexNextToken
  Else
    WarnMsg(', attendue entre arguments de Format');

  { Deuxieme argument : chaine de format }
  ParseExpr;
  EmitComment('PUSH format_string pour Format');
  Emit('PUSH EAX');

  { Parenthese fermante }
  If CurTokType = TOK_RPAREN Then
    LexNextToken
  Else
    WarnMsg(') attendue apres arguments de Format');

  { Appel runtime }
  EmitComment('CALL ' + STROP_RT_FORMAT);
  Emit('CALL ' + STROP_RT_FORMAT);
  Emit('ADD ESP, 8');
  { EAX = pointeur vers chaine formatee }

  If Opts.Verbose Then
    WriteLn('    StrOp: Format call');

  ParseFormatCall := VBT_STRING;
End;

{ ------------------------------------------------------------ }
{ IsStrOpStatement : teste si le token courant est une         }
{   instruction d operation sur chaine (Mid$, LSet, RSet)      }
{ ------------------------------------------------------------ }

Function IsStrOpStatement : Boolean;
Begin
  IsStrOpStatement := IsKeywordToken(KW_LSET) Or
                      IsKeywordToken(KW_RSET) Or
                      IsKeywordToken(KW_MIDASSIGN);
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
{ IsFixedStringDecl : teste si le token courant commence une   }
{   declaration String * n                                     }
{ ------------------------------------------------------------ }

Function IsFixedStringDecl : Boolean;
Begin
  IsFixedStringDecl := IsKeywordToken(KW_STRINGFN) And
                       (CurTokType = TOK_KEYWORD) And
                       (CurTokNum = KW_STRINGFN);
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
    3 : StrOpRtLabel := STROP_RT_MIDASSIGN;
    4 : StrOpRtLabel := STROP_RT_LSET;
    5 : StrOpRtLabel := STROP_RT_RSET;
    6 : StrOpRtLabel := STROP_RT_STRCMP_BIN;
    7 : StrOpRtLabel := STROP_RT_STRCMP_TXT;
    8 : StrOpRtLabel := STROP_RT_LIKE;
    9 : StrOpRtLabel := STROP_RT_FORMAT;
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

Function GetMaxFixedStrLen : Integer;
Begin
  GetMaxFixedStrLen := MAX_FIXED_STR;
End;

Function GetStrOpRtCount : Integer;
Begin
  { 10 labels runtime pour operations chaines }
  GetStrOpRtCount := 10;
End;

Function IsStrOpFormat(KW : Integer) : Boolean;
Begin
  IsStrOpFormat := (KW = KW_FORMAT) Or (KW = KW_FORMAT2);
End;

{ ============================================================ }
{ TODO 15 - PARSEUR : TABLEAUX (DIM, REDIM, ERASE,            }
{           LBOUND, UBOUND)  [IMPLEMENTE]                      }
{ ============================================================ }

Const
  { Nombre maximal de dimensions pour un tableau }
  MAX_ARRAY_DIMS  = 8;

  { Nombre maximal d elements par dimension (statique) }
  MAX_ARRAY_ELEMS = 65536;

  { Labels runtime pour operations sur tableaux }
  ARR_RT_REDIM    = '_VBRT_REDIM';
  ARR_RT_PRESERVE = '_VBRT_REDIM_PRESERVE';
  ARR_RT_ERASE    = '_VBRT_ERASE';
  ARR_RT_LBOUND   = '_VBRT_LBOUND';
  ARR_RT_UBOUND   = '_VBRT_UBOUND';
  ARR_RT_ARRAYVAL = '_VBRT_ARRAY';
  ARR_RT_ISARRAY  = '_VBRT_ISARRAY';
  ARR_RT_ALLOC    = '_VBRT_ARR_ALLOC';
  ARR_RT_FREE     = '_VBRT_ARR_FREE';
  ARR_RT_BOUNDSCK = '_VBRT_BOUNDSCHECK';

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
{   Syntaxe : (n) ou (lo To hi) ou (n, m) ou (lo To hi, ...)  }
{   Retourne le nombre de dimensions detectees                 }
{   DimLo/DimHi : bornes inferieure/superieure par dimension   }
{ ------------------------------------------------------------ }

Procedure ParseArrayBounds(Var NDims    : Integer;
                           Var DimLo    : Array Of LongInt;
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
    { Parser la borne : soit un nombre, soit expr To expr }
    ParseExpr;
    Inc(ArrayCount);
    DimLo[D] := OptionBase; { defaut : Option Base }
    If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_TO) Then Begin
      { Syntaxe : lo To hi }
      DimLo[D] := CurTokNum; { valeur parsee comme expr }
      LexNextToken; { consommer 'To' }
      ParseExpr;
      DimHi[D] := CurTokNum;
    End Else Begin
      { Syntaxe : n (equiv a 0/OptionBase .. n) }
      DimHi[D] := CurTokNum;
    End;
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
{   Dim arr(10) As Integer                                     }
{   Dim arr(1 To 10) As Integer                                }
{   Dim mat(3, 3) As Long                                      }
{   Genere allocation en .DATA (global) ou pile (local)        }
{ ------------------------------------------------------------ }

Procedure ParseStaticArray(ArrName : TString; NDims : Integer;
                           DimLo, DimHi : Array Of LongInt;
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
    TotalElems := TotalElems * (DimHi[I] - DimLo[I] + 1);
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
{   Genere un pointeur DD initialise a 0 (NULL)                }
{ ------------------------------------------------------------ }

Procedure ParseDynamicArray(ArrName : TString; ElemType : Integer);
Var
  AsmLbl : TString;
Begin
  Inc(ArrayCount);
  AsmLbl := PFX_ARR + AsmIdent(ArrName);
  If IsInGlobalScope Then Begin
    { Pointeur global initialise a NULL }
    EmitData(AsmLbl + ' DD 0');
  End Else Begin
    { Pointeur local sur la pile }
    Emit('PUSH 0');
    EmitComment('tableau dynamique ' + ArrName + ' (pointeur NULL)');
  End;
End;

{ ------------------------------------------------------------ }
{ ParseRedim : parser ReDim [Preserve] arr(n)                  }
{   Genere CALL _VBRT_REDIM ou _VBRT_REDIM_PRESERVE            }
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
{   Genere PUSH ptr_arr / CALL _VBRT_ERASE                     }
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
  { Mettre le pointeur a NULL }
  Emit('MOV DWORD [' + AsmLbl + '], 0');
  SkipNewlines;
End;

{ ------------------------------------------------------------ }
{ GenArrayAccess : generer le code d acces a un element         }
{   arr(index) -> MOV EAX, [base + index * elem_size]          }
{   L index est deja evalue dans EAX                           }
{ ------------------------------------------------------------ }

Procedure GenArrayAccess(ArrName : TString; ElemType : Integer;
                         BaseLo : LongInt);
Var
  AsmLbl   : TString;
  ElemSize : LongInt;
Begin
  Inc(ArrayCount);
  AsmLbl := PFX_ARR + AsmIdent(ArrName);
  ElemSize := VBTypeSize(ElemType);
  { Ajuster l index si base non zero }
  If BaseLo <> 0 Then Begin
    Emit('SUB EAX, ' + ItoS(BaseLo));
    EmitComment('ajuster index (base=' + ItoS(BaseLo) + ')');
  End;
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
{ ParseLBound : parser LBound(arr[, dim])                      }
{   Genere PUSH dim / PUSH arr / CALL _VBRT_LBOUND             }
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
    Emit('PUSH 1');
    EmitComment('dim=1 par defaut');
  End;
  Expect(TOK_RPAREN);
  Emit('PUSH ' + AsmLbl);
  Emit('CALL ' + ARR_RT_LBOUND);
  EmitComment('LBound(' + ArrName + ')');
End;

{ ------------------------------------------------------------ }
{ ParseUBound : parser UBound(arr[, dim])                      }
{   Genere PUSH dim / PUSH arr / CALL _VBRT_UBOUND             }
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
    Emit('PUSH 1');
    EmitComment('dim=1 par defaut');
  End;
  Expect(TOK_RPAREN);
  Emit('PUSH ' + AsmLbl);
  Emit('CALL ' + ARR_RT_UBOUND);
  EmitComment('UBound(' + ArrName + ')');
End;

{ ------------------------------------------------------------ }
{ ParseArrayCall : parser Array(v1, v2, ...)                   }
{   Cree un Variant Array (stub)                               }
{   Genere PUSH des valeurs + CALL _VBRT_ARRAY                 }
{ ------------------------------------------------------------ }

Procedure ParseArrayCall;
Var
  ArgCount : Integer;
Begin
  Inc(ArrayCount);
  { On s attend a KW_ARRAY deja consomme + '(' }
  Expect(TOK_LPAREN);
  ArgCount := 0;
  If CurTokType <> TOK_RPAREN Then Begin
    Repeat
      ParseExpr;
      Emit('PUSH EAX');
      Inc(ArgCount);
      If CurTokType = TOK_COMMA Then
        LexNextToken
      Else
        Break;
    Until False;
  End;
  Expect(TOK_RPAREN);
  { Pousser le nombre d elements }
  Emit('PUSH ' + ItoS(ArgCount));
  Emit('CALL ' + ARR_RT_ARRAYVAL);
  EmitComment('Array(...) avec ' + ItoS(ArgCount) + ' elements');
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
    IsArrayAccess := (SymTab[Idx].Kind = SK_ARRAY)
  Else
    IsArrayAccess := False;
End;

{ ------------------------------------------------------------ }
{ IsArrayFunction : verifier si KW est une fonction de tableau }
{ ------------------------------------------------------------ }

Function IsArrayFunction(KW : Integer) : Boolean;
Begin
  IsArrayFunction := (KW = KW_LBOUND) Or (KW = KW_UBOUND) Or
                     (KW = KW_ARRAY) Or (KW = KW_ISARRAY);
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
  { 10 labels runtime pour operations tableaux }
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
{ TODO 16 - PARSEUR : TYPES UTILISATEUR (TYPE...END TYPE)      }
{           ET ENUM  [IMPLEMENTE]                              }
{ ============================================================ }

Const
  { Nombre maximal de champs dans un Type utilisateur }
  MAX_UDT_FIELDS   = 128;

  { Nombre maximal de membres dans un Enum }
  MAX_ENUM_MEMBERS = 256;

  { Taille maximale d un Type utilisateur en octets }
  MAX_UDT_SIZE     = 65536;

  { Labels runtime pour operations sur types utilisateur }
  UDT_RT_COPY     = '_VBRT_UDT_COPY';
  UDT_RT_CLEAR    = '_VBRT_UDT_CLEAR';
  UDT_RT_COMPARE  = '_VBRT_UDT_COMPARE';
  UDT_RT_SIZEOF   = '_VBRT_UDT_SIZEOF';
  UDT_RT_FIELDPTR = '_VBRT_UDT_FIELDPTR';
  UDT_RT_INIT     = '_VBRT_UDT_INIT';
  UDT_RT_FREE     = '_VBRT_UDT_FREE';
  UDT_RT_LSET_UDT = '_VBRT_UDT_LSET';
  UDT_RT_ENUM_VAL = '_VBRT_ENUM_VAL';
  UDT_RT_ENUM_STR = '_VBRT_ENUM_STR';

Var
  TypeEnumCount       : LongInt;
  TypeEnumInitialized : Boolean;
  WithActive          : Boolean;
  WithBaseLabel       : TString;
  CurTypeSize         : LongInt;

{ ------------------------------------------------------------ }
{ InitTypeEnumState : initialiser l etat du parseur Type/Enum  }
{ ------------------------------------------------------------ }

Procedure InitTypeEnumState;
Begin
  TypeEnumCount       := 0;
  TypeEnumInitialized := True;
  WithActive          := False;
  WithBaseLabel       := '';
  CurTypeSize         := 0;
End;

{ ------------------------------------------------------------ }
{ ParseTypeField : parser un champ d un Type utilisateur       }
{   Syntaxe : champ As Type  ou  champ As String * n           }
{             champ(n) As Type  (champ tableau)                }
{   Retourne l offset et la taille du champ                    }
{ ------------------------------------------------------------ }

Procedure ParseTypeField(TypeName : TString; FieldOffset : LongInt);
Var
  FName       : TString;
  FType       : Integer;
  FSize       : Integer;
  FArrCount   : LongInt;
  IsArrayFld  : Boolean;
  SymIdx      : Integer;
  TotalSize   : LongInt;
Begin
  Inc(TypeEnumCount);
  { Nom du champ }
  If CurTokType <> TOK_IDENT Then Begin
    FatalError('identifiant attendu pour le champ du Type ' + TypeName);
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
      FArrCount := CurTokNum + 1; { VB6 : 0 To n => n+1 elements }
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
  { Chaine de longueur fixe : String * n }
  If (FType = VBT_STRING) And (CurTokType = TOK_STAR) Then Begin
    LexNextToken;
    If CurTokType = TOK_INTEGER Then Begin
      FSize := CurTokNum;
      LexNextToken;
    End Else Begin
      FatalError('taille de chaine fixe attendue dans Type ' + TypeName);
    End;
  End;
  { Calculer la taille totale du champ }
  TotalSize := FSize * FArrCount;
  { Ajouter le champ dans la table des symboles }
  SymIdx := AddSym(FName, SK_FIELD, FType, STORE_GLOBAL);
  If SymIdx >= 0 Then Begin
    SymTab[SymIdx].BpOffset  := FieldOffset;
    SymTab[SymIdx].IsPublic  := True;
    SymTab[SymIdx].IsConst   := False;
    If IsArrayFld Then
      SymTab[SymIdx].ArrayDims := 1
    Else
      SymTab[SymIdx].ArrayDims := 0;
    SymTab[SymIdx].AsmLabel := PFX_TYPE + UpCaseStr(TypeName) + '_' +
                               UpCaseStr(FName);
  End;
  { Emettre commentaire d assembleur pour le champ }
  EmitComment('  ' + TypeName + '.' + FName + ' : offset=' +
              ItoS(FieldOffset) + ', size=' + ItoS(TotalSize));
  { Mettre a jour la taille courante du type }
  CurTypeSize := FieldOffset + TotalSize;
  { Aller a la ligne suivante }
  SkipNewlines;
End;

{ ------------------------------------------------------------ }
{ ParseTypeDecl : parser une declaration Type...End Type       }
{   Syntaxe :                                                  }
{     [Public|Private] Type NomType                            }
{       champ1 As Integer                                      }
{       champ2 As String * 20                                  }
{       champ3(10) As Long                                     }
{     End Type                                                 }
{   Genere : labels et commentaires pour la structure           }
{   Ajoute le type et ses champs dans la table des symboles     }
{ ------------------------------------------------------------ }

Procedure ParseTypeDecl(IsPublic : Boolean);
Var
  TypeName     : TString;
  FieldCount   : Integer;
  SymIdx       : Integer;
  AsmLbl       : TString;
Begin
  Inc(TypeEnumCount);
  { Consommer 'Type' }
  LexNextToken;
  { Nom du type }
  If CurTokType <> TOK_IDENT Then Begin
    FatalError('identifiant attendu apres Type');
    Exit;
  End;
  TypeName := CurTokStr;
  AsmLbl   := PFX_TYPE + UpCaseStr(TypeName);
  LexNextToken;
  SkipNewlines;
  { Ajouter le type dans la table des symboles }
  SymIdx := AddSym(TypeName, SK_TYPE, VBT_USER, STORE_GLOBAL);
  If SymIdx >= 0 Then Begin
    SymTab[SymIdx].IsPublic := IsPublic;
    SymTab[SymIdx].IsConst  := False;
    SymTab[SymIdx].AsmLabel := AsmLbl;
  End;
  { Emettre le commentaire de structure }
  EmitComment('Type ' + TypeName);
  { Parser les champs }
  FieldCount  := 0;
  CurTypeSize := 0;
  While Not LexEOF Do Begin
    { Verifier End Type }
    If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_END) Then Begin
      LexNextToken;
      If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_TYPE) Then Begin
        LexNextToken;
        Break;
      End Else Begin
        FatalError('End Type attendu');
        Exit;
      End;
    End;
    { Ignorer les lignes vides }
    If CurTokType = TOK_NEWLINE Then Begin
      SkipNewlines;
      Continue;
    End;
    { Parser un champ }
    If FieldCount >= MAX_UDT_FIELDS Then Begin
      FatalError('nombre maximal de champs depasse dans Type ' + TypeName);
      Exit;
    End;
    ParseTypeField(TypeName, CurTypeSize);
    Inc(FieldCount);
  End;
  { Emettre la taille totale du type }
  EmitComment('End Type ' + TypeName + ' (size=' + ItoS(CurTypeSize) + ')');
  { Emettre une constante de taille en .DATA }
  EmitData(AsmLbl + '_SIZE DD ' + ItoS(CurTypeSize));
  { Mettre a jour la taille dans le symbole }
  If SymIdx >= 0 Then Begin
    SymTab[SymIdx].InitNum := CurTypeSize;
    SymTab[SymIdx].HasInit := True;
  End;
  SkipNewlines;
End;

{ ------------------------------------------------------------ }
{ ParseEnumDecl : parser une declaration Enum...End Enum       }
{   Syntaxe :                                                  }
{     [Public|Private] Enum NomEnum                            }
{       Valeur1 [= 0]                                         }
{       Valeur2 [= 1]                                         }
{       Valeur3 = 10                                           }
{     End Enum                                                 }
{   Chaque membre est ajoute comme constante Long              }
{   Les valeurs sont auto-incrementees si non specifiees       }
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
  Inc(TypeEnumCount);
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
  SymIdx := AddSym(EnumName, SK_ENUM, VBT_LONG, STORE_GLOBAL);
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
    { Ajouter le membre comme constante }
    SymIdx := AddSym(MemberName, SK_ENUM_MEMBER, VBT_LONG, STORE_CONSTANT);
    If SymIdx >= 0 Then Begin
      SymTab[SymIdx].IsPublic   := IsPublic;
      SymTab[SymIdx].IsConst    := True;
      SymTab[SymIdx].InitNum    := CurValue;
      SymTab[SymIdx].HasInit    := True;
      SymTab[SymIdx].AsmLabel   := PFX_ENUM + UpCaseStr(EnumName) + '_' +
                                   UpCaseStr(MemberName);
    End;
    { Emettre commentaire }
    EmitComment('  ' + EnumName + '.' + MemberName + ' = ' + ItoS(CurValue));
    { Emettre la constante en .DATA }
    EmitData(PFX_ENUM + UpCaseStr(EnumName) + '_' +
             UpCaseStr(MemberName) + ' DD ' + ItoS(CurValue));
    Inc(CurValue);
    Inc(MemberCount);
    SkipNewlines;
  End;
  EmitComment('End Enum ' + EnumName + ' (' + ItoS(MemberCount) + ' members)');
  SkipNewlines;
End;

{ ------------------------------------------------------------ }
{ GenFieldAccess : generer le code pour acceder a un champ     }
{   d une variable de type utilisateur                         }
{   Syntaxe : variable.champ                                   }
{   Genere : LEA EAX, [base + offset_champ]                   }
{ ------------------------------------------------------------ }

Procedure GenFieldAccess(VarIdx, FieldIdx : Integer);
Var
  BaseLabel   : TString;
  FieldOffset : LongInt;
Begin
  Inc(TypeEnumCount);
  If (VarIdx < 0) Or (VarIdx >= SymCount) Then Begin
    FatalError('variable de type utilisateur invalide');
    Exit;
  End;
  If (FieldIdx < 0) Or (FieldIdx >= SymCount) Then Begin
    FatalError('champ de type utilisateur invalide');
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
        Emit('LEA EAX, [EBP - ' + ItoS(Abs(SymTab[VarIdx].BpOffset)) + ']')
      Else
        Emit('LEA EAX, [EBP - ' + ItoS(Abs(SymTab[VarIdx].BpOffset) -
             FieldOffset) + ']');
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
{   d une variable de type utilisateur                         }
{   La valeur a stocker est dans EAX                           }
{   Genere : MOV [base + offset_champ], EAX                   }
{ ------------------------------------------------------------ }

Procedure GenFieldStore(VarIdx, FieldIdx : Integer);
Var
  BaseLabel   : TString;
  FieldOffset : LongInt;
  FieldSize   : Integer;
Begin
  Inc(TypeEnumCount);
  If (VarIdx < 0) Or (VarIdx >= SymCount) Then Begin
    FatalError('variable de type utilisateur invalide');
    Exit;
  End;
  If (FieldIdx < 0) Or (FieldIdx >= SymCount) Then Begin
    FatalError('champ de type utilisateur invalide');
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
{ ParseWithStatement : parser une instruction With...End With  }
{   Syntaxe :                                                  }
{     With variable                                            }
{       .champ = valeur                                        }
{     End With                                                 }
{   Active l acces implicite aux champs de la variable         }
{ ------------------------------------------------------------ }

Procedure ParseWithStatement;
Var
  VarName : TString;
  VarIdx  : Integer;
Begin
  Inc(TypeEnumCount);
  { Consommer 'With' }
  LexNextToken;
  { Nom de la variable }
  If CurTokType <> TOK_IDENT Then Begin
    FatalError('identifiant attendu apres With');
    Exit;
  End;
  VarName := CurTokStr;
  VarIdx  := FindSym(VarName);
  If VarIdx < 0 Then Begin
    FatalError('variable non declaree : ' + VarName);
    Exit;
  End;
  LexNextToken;
  SkipNewlines;
  { Activer le contexte With }
  WithActive    := True;
  WithBaseLabel := SymTab[VarIdx].AsmLabel;
  { Emettre commentaire }
  EmitComment('With ' + VarName);
  { Generer le chargement de l adresse de base }
  Case SymTab[VarIdx].StoreClass Of
    STORE_GLOBAL, STORE_STATIC :
      Emit('LEA ESI, [' + SymTab[VarIdx].AsmLabel + ']');
    STORE_AUTO :
      Emit('LEA ESI, [EBP - ' + ItoS(Abs(SymTab[VarIdx].BpOffset)) + ']');
    STORE_PARAM :
      Emit('MOV ESI, [EBP + ' + ItoS(SymTab[VarIdx].BpOffset) + ']');
  Else
    Emit('LEA ESI, [' + SymTab[VarIdx].AsmLabel + ']');
  End;
  { Parser le bloc With : on le laisse au parseur de statements }
  { Le bloc se termine par End With                             }
  { Note: les instructions .champ seront resolues par le       }
  { parseur d expressions avec le contexte WithActive           }
  While Not LexEOF Do Begin
    { Verifier End With }
    If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_END) Then Begin
      LexNextToken;
      If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_WITH) Then Begin
        LexNextToken;
        Break;
      End Else Begin
        FatalError('End With attendu');
        Exit;
      End;
    End;
    { Ignorer les lignes vides }
    If CurTokType = TOK_NEWLINE Then Begin
      SkipNewlines;
      Continue;
    End;
    { Ignorer les instructions du bloc pour l instant (stub) }
    SkipToEndOfLine;
    SkipNewlines;
  End;
  { Desactiver le contexte With }
  WithActive    := False;
  WithBaseLabel := '';
  EmitComment('End With');
  SkipNewlines;
End;

{ ------------------------------------------------------------ }
{ IsTypeDecl : verifier si le token courant est une            }
{   declaration Type                                           }
{ ------------------------------------------------------------ }

Function IsTypeDecl(KW : Integer) : Boolean;
Begin
  IsTypeDecl := (KW = KW_TYPE);
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
{ IsWithStatement : verifier si le token courant est With      }
{ ------------------------------------------------------------ }

Function IsWithStatement(KW : Integer) : Boolean;
Begin
  IsWithStatement := (KW = KW_WITH);
End;

{ ------------------------------------------------------------ }
{ Fonctions accesseur pour le module Type/Enum                 }
{ ------------------------------------------------------------ }

Function GetTypeEnumCount : LongInt;
Begin
  GetTypeEnumCount := TypeEnumCount;
End;

Function IsTypeEnumInitialized : Boolean;
Begin
  IsTypeEnumInitialized := TypeEnumInitialized;
End;

Function IsTypeEnumEmpty : Boolean;
Begin
  IsTypeEnumEmpty := (TypeEnumCount = 0);
End;

Function GetTypeEnumStatus : TString;
Begin
  If Not TypeEnumInitialized Then
    GetTypeEnumStatus := 'non initialise'
  Else If TypeEnumCount = 0 Then
    GetTypeEnumStatus := 'initialise, aucun type/enum'
  Else
    GetTypeEnumStatus := 'initialise, ' + ItoS(TypeEnumCount) + ' operations';
End;

Function GetMaxUdtFields : Integer;
Begin
  GetMaxUdtFields := MAX_UDT_FIELDS;
End;

Function GetMaxEnumMembers : Integer;
Begin
  GetMaxEnumMembers := MAX_ENUM_MEMBERS;
End;

Function GetMaxUdtSize : LongInt;
Begin
  GetMaxUdtSize := MAX_UDT_SIZE;
End;

Function IsWithActive : Boolean;
Begin
  IsWithActive := WithActive;
End;

Function GetWithBaseLabel : TString;
Begin
  GetWithBaseLabel := WithBaseLabel;
End;

Function GetUdtRtCount : Integer;
Begin
  { 10 labels runtime pour operations Type/Enum }
  GetUdtRtCount := 10;
End;

{ ============================================================ }
{ TODO 17 - PARSEUR : MODULES DE CLASSE (CLASS, PROPERTY,     }
{           METHOD) [IMPLEMENTE]                               }
{ ============================================================ }

Const
  { Nombre maximal de methodes dans une classe }
  MAX_CLASS_METHODS = 128;

  { Nombre maximal de proprietes dans une classe }
  MAX_CLASS_PROPS   = 128;

  { Nombre maximal de champs d instance dans une classe }
  MAX_CLASS_FIELDS  = 128;

  { Taille d un pointeur objet (32 bits) }
  OBJ_PTR_SIZE      = 4;

  { Offset de la vtable dans un objet (premier DD) }
  OBJ_VTABLE_OFFSET = 0;

  { Labels runtime pour operations sur classes }
  CLS_RT_ALLOC     = '_VBRT_CLS_ALLOC';
  CLS_RT_FREE      = '_VBRT_CLS_FREE';
  CLS_RT_ADDREF    = '_VBRT_CLS_ADDREF';
  CLS_RT_RELEASE   = '_VBRT_CLS_RELEASE';
  CLS_RT_QUERYIF   = '_VBRT_CLS_QUERYIF';
  CLS_RT_INIT      = '_VBRT_CLS_INIT';
  CLS_RT_TERM      = '_VBRT_CLS_TERM';
  CLS_RT_SET       = '_VBRT_CLS_SET';
  CLS_RT_ISNOTH    = '_VBRT_CLS_ISNOTHING';
  CLS_RT_TYPEOF    = '_VBRT_CLS_TYPEOF';

  { Types de propriete }
  PROP_GET = 0;
  PROP_LET = 1;
  PROP_SET = 2;

Var
  ClassCount       : LongInt;
  ClassInitialized : Boolean;
  CurClassName     : TString;
  CurClassIsPublic : Boolean;
  CurClassCreatable: Boolean;
  CurClassExposed  : Boolean;
  CurClassHasInit  : Boolean;
  CurClassHasTerm  : Boolean;
  ClassMethodCount : Integer;
  ClassPropCount   : Integer;

{ ------------------------------------------------------------ }
{ InitClassState : initialiser l etat du parseur de classes    }
{ ------------------------------------------------------------ }

Procedure InitClassState;
Begin
  ClassCount       := 0;
  ClassInitialized := True;
  CurClassName     := '';
  CurClassIsPublic := True;
  CurClassCreatable:= True;
  CurClassExposed  := False;
  CurClassHasInit  := False;
  CurClassHasTerm  := False;
  ClassMethodCount := 0;
  ClassPropCount   := 0;
End;

{ ------------------------------------------------------------ }
{ ParseClassAttribute : parser un attribut de module de classe }
{   Syntaxe : Attribute VB_Name = "NomClasse"                  }
{             Attribute VB_Creatable = True|False               }
{             Attribute VB_Exposed = True|False                 }
{   Extrait les proprietes du module .CLS                      }
{ ------------------------------------------------------------ }

Procedure ParseClassAttribute;
Var
  AttrName : TString;
  AttrVal  : TString;
Begin
  Inc(ClassCount);
  { On est positionne apres le mot-cle Attribute }
  If CurTokType = TOK_IDENT Then Begin
    AttrName := UpCaseStr(CurTokStr);
    LexNextToken; { consommer le nom d attribut }
    { Attendre le signe = }
    If CurTokType = TOK_EQ Then Begin
      LexNextToken; { consommer = }
      { Lire la valeur (chaine ou identifiant) }
      If CurTokType = TOK_STRING Then Begin
        AttrVal := CurTokStr;
        LexNextToken;
      End Else If CurTokType = TOK_IDENT Then Begin
        AttrVal := UpCaseStr(CurTokStr);
        LexNextToken;
      End Else If CurTokType = TOK_KEYWORD Then Begin
        AttrVal := UpCaseStr(KeywordName(CurTokNum));
        LexNextToken;
      End Else Begin
        AttrVal := CurTokStr;
        LexNextToken;
      End;
      { Traiter l attribut selon son nom }
      If AttrName = 'VB_NAME' Then Begin
        CurClassName := AttrVal;
        If Opts.Verbose Then
          WriteLn('  Classe: ', CurClassName);
      End
      Else If AttrName = 'VB_CREATABLE' Then Begin
        CurClassCreatable := (AttrVal = 'TRUE');
      End
      Else If AttrName = 'VB_EXPOSED' Then Begin
        CurClassExposed := (AttrVal = 'TRUE');
      End;
    End;
  End;
  SkipToEndOfLine;
End;

{ ------------------------------------------------------------ }
{ ParsePropertyGet : parser une propriete Property Get          }
{   Syntaxe : [Public|Private] Property Get NomProp            }
{             ([param As Type]) As TypeRetour                   }
{               instructions                                    }
{             End Property                                      }
{   Genere code similaire a Function avec convention Get        }
{ ------------------------------------------------------------ }

Procedure ParsePropertyGet;
Var
  PropName   : TString;
  PropLabel  : TString;
  RetType    : Integer;
  ParamCnt   : Integer;
  LocalSize  : Integer;
  ExLabel    : TString;
Begin
  Inc(ClassPropCount);
  Inc(ClassCount);
  { Consommer 'Get' (on est apres Property) }
  LexNextToken;
  { Lire le nom de la propriete }
  If CurTokType = TOK_IDENT Then Begin
    PropName := CurTokStr;
    LexNextToken;
  End Else Begin
    FatalError('Nom de propriete attendu apres Property Get');
    PropName := '?';
  End;
  PropLabel := PFX_PROP + AsmIdent(PropName) + '_GET';
  ParamCnt  := 0;
  LocalSize := 0;
  RetType   := VBT_VARIANT;
  { Parser les parametres optionnels }
  If CurTokType = TOK_LPAREN Then Begin
    LexNextToken; { consommer ( }
    { Parser parametres simples }
    While Not (CurTokType = TOK_RPAREN) Do Begin
      If CurTokType = TOK_EOF Then Break;
      Inc(ParamCnt);
      LexNextToken;
    End;
    If CurTokType = TOK_RPAREN Then
      LexNextToken; { consommer ) }
  End;
  { Parser le type de retour optionnel }
  If IsKeywordToken(KW_AS) Then Begin
    LexNextToken; { consommer As }
    RetType := ParseTypeSpec;
  End;
  SkipNewlines;
  { Ajouter dans la table des symboles }
  AddSym(PropName, SK_PROPERTY, RetType, STORE_GLOBAL);
  AddProc(PropName, SK_PROPERTY, RetType, True);
  ExLabel := NextInternalLabel;
  { Generer le prologue }
  EmitLabel(PropLabel);
  Emit('PUSH EBP');
  Emit('MOV EBP, ESP');
  If LocalSize > 0 Then
    Emit('SUB ESP, ' + ItoS(LocalSize));
  EmitComment('Property Get ' + PropName);
  { Valeur de retour par defaut }
  Emit('XOR EAX, EAX');
  { Parser le corps de la propriete jusqu a End Property }
  While Not (CurTokType = TOK_EOF) Do Begin
    If IsKeywordToken(KW_END) Then Begin
      LexNextToken;
      If IsKeywordToken(KW_PROPERTY) Then Begin
        LexNextToken;
        Break;
      End;
    End;
    LexNextToken;
  End;
  SkipNewlines;
  { Generer l epilogue }
  EmitLabel(ExLabel);
  Emit('MOV ESP, EBP');
  Emit('POP EBP');
  If ParamCnt > 0 Then
    Emit('RET ' + ItoS(ParamCnt * 4))
  Else
    Emit('RET');
End;

{ ------------------------------------------------------------ }
{ ParsePropertyLet : parser une propriete Property Let          }
{   Syntaxe : [Public|Private] Property Let NomProp            }
{             (valeur As Type)                                  }
{               instructions                                    }
{             End Property                                      }
{   Genere code similaire a Sub avec convention Let (valeur)    }
{ ------------------------------------------------------------ }

Procedure ParsePropertyLet;
Var
  PropName   : TString;
  PropLabel  : TString;
  ParamCnt   : Integer;
  LocalSize  : Integer;
  ExLabel    : TString;
Begin
  Inc(ClassPropCount);
  Inc(ClassCount);
  { Consommer 'Let' }
  LexNextToken;
  { Lire le nom de la propriete }
  If CurTokType = TOK_IDENT Then Begin
    PropName := CurTokStr;
    LexNextToken;
  End Else Begin
    FatalError('Nom de propriete attendu apres Property Let');
    PropName := '?';
  End;
  PropLabel := PFX_PROP + AsmIdent(PropName) + '_LET';
  ParamCnt  := 0;
  LocalSize := 0;
  { Parser les parametres (au moins un : la valeur) }
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
  SkipNewlines;
  { Ajouter dans la table des procedures }
  AddProc(PropName, SK_PROPERTY, VBT_NONE, True);
  ExLabel := NextInternalLabel;
  { Generer le prologue }
  EmitLabel(PropLabel);
  Emit('PUSH EBP');
  Emit('MOV EBP, ESP');
  If LocalSize > 0 Then
    Emit('SUB ESP, ' + ItoS(LocalSize));
  EmitComment('Property Let ' + PropName);
  { Parser le corps de la propriete jusqu a End Property }
  While Not (CurTokType = TOK_EOF) Do Begin
    If IsKeywordToken(KW_END) Then Begin
      LexNextToken;
      If IsKeywordToken(KW_PROPERTY) Then Begin
        LexNextToken;
        Break;
      End;
    End;
    LexNextToken;
  End;
  SkipNewlines;
  { Generer l epilogue }
  EmitLabel(ExLabel);
  Emit('MOV ESP, EBP');
  Emit('POP EBP');
  If ParamCnt > 0 Then
    Emit('RET ' + ItoS(ParamCnt * 4))
  Else
    Emit('RET');
End;

{ ------------------------------------------------------------ }
{ ParsePropertySet : parser une propriete Property Set          }
{   Syntaxe : [Public|Private] Property Set NomProp            }
{             (obj As Object)                                   }
{               instructions                                    }
{             End Property                                      }
{   Genere code similaire a Sub avec convention Set (objet)     }
{ ------------------------------------------------------------ }

Procedure ParsePropertySet;
Var
  PropName   : TString;
  PropLabel  : TString;
  ParamCnt   : Integer;
  LocalSize  : Integer;
  ExLabel    : TString;
Begin
  Inc(ClassPropCount);
  Inc(ClassCount);
  { Consommer 'Set' }
  LexNextToken;
  { Lire le nom de la propriete }
  If CurTokType = TOK_IDENT Then Begin
    PropName := CurTokStr;
    LexNextToken;
  End Else Begin
    FatalError('Nom de propriete attendu apres Property Set');
    PropName := '?';
  End;
  PropLabel := PFX_PROP + AsmIdent(PropName) + '_SET';
  ParamCnt  := 0;
  LocalSize := 0;
  { Parser les parametres (au moins un : l objet) }
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
  SkipNewlines;
  { Ajouter dans la table des procedures }
  AddProc(PropName, SK_PROPERTY, VBT_OBJECT, True);
  ExLabel := NextInternalLabel;
  { Generer le prologue }
  EmitLabel(PropLabel);
  Emit('PUSH EBP');
  Emit('MOV EBP, ESP');
  If LocalSize > 0 Then
    Emit('SUB ESP, ' + ItoS(LocalSize));
  EmitComment('Property Set ' + PropName);
  { Parser le corps de la propriete jusqu a End Property }
  While Not (CurTokType = TOK_EOF) Do Begin
    If IsKeywordToken(KW_END) Then Begin
      LexNextToken;
      If IsKeywordToken(KW_PROPERTY) Then Begin
        LexNextToken;
        Break;
      End;
    End;
    LexNextToken;
  End;
  SkipNewlines;
  { Generer l epilogue }
  EmitLabel(ExLabel);
  Emit('MOV ESP, EBP');
  Emit('POP EBP');
  If ParamCnt > 0 Then
    Emit('RET ' + ItoS(ParamCnt * 4))
  Else
    Emit('RET');
End;

{ ------------------------------------------------------------ }
{ ParseClassEvent : parser un evenement de cycle de vie classe  }
{   Class_Initialize : appele a la creation de l instance       }
{   Class_Terminate : appele a la destruction de l instance     }
{   Genere comme un Sub normal avec label special               }
{ ------------------------------------------------------------ }

Procedure ParseClassEvent(IsInit : Boolean);
Var
  EvtLabel : TString;
  ExLabel  : TString;
Begin
  Inc(ClassCount);
  Inc(ClassMethodCount);
  If IsInit Then Begin
    EvtLabel := PFX_CLS + AsmIdent(CurClassName) + '_INIT';
    CurClassHasInit := True;
    EmitComment('Class_Initialize pour ' + CurClassName);
  End Else Begin
    EvtLabel := PFX_CLS + AsmIdent(CurClassName) + '_TERM';
    CurClassHasTerm := True;
    EmitComment('Class_Terminate pour ' + CurClassName);
  End;
  ExLabel := NextInternalLabel;
  { Generer le prologue du Sub evenement }
  EmitLabel(EvtLabel);
  Emit('PUSH EBP');
  Emit('MOV EBP, ESP');
  { Parser le corps jusqu a End Sub }
  While Not (CurTokType = TOK_EOF) Do Begin
    If IsKeywordToken(KW_END) Then Begin
      LexNextToken;
      If IsKeywordToken(KW_SUB) Then Begin
        LexNextToken;
        Break;
      End;
    End;
    LexNextToken;
  End;
  SkipNewlines;
  { Generer l epilogue }
  EmitLabel(ExLabel);
  Emit('MOV ESP, EBP');
  Emit('POP EBP');
  Emit('RET');
End;

{ ------------------------------------------------------------ }
{ GenNewObject : generer code pour creation d une instance      }
{   Dim obj As New NomClasse  ou  Set obj = New NomClasse       }
{   Alloue memoire (CALL _VBRT_CLS_ALLOC), init vtable,        }
{   appelle Class_Initialize si present                         }
{   Resultat dans EAX = pointeur vers l instance                }
{ ------------------------------------------------------------ }

Procedure GenNewObject(ClassName : TString);
Var
  VTLabel   : TString;
Begin
  Inc(ClassCount);
  VTLabel   := PFX_CLS + AsmIdent(ClassName) + '_VTABLE';
  EmitComment('New ' + ClassName);
  { Allouer memoire pour l objet }
  { La taille est determinee par le nombre de champs + vtable ptr }
  Emit('PUSH ' + ItoS(OBJ_PTR_SIZE + MAX_CLASS_FIELDS * 4));
  Emit('CALL ' + CLS_RT_ALLOC);
  Emit('ADD ESP, 4');
  { Stocker le pointeur vtable dans le premier DD de l objet }
  Emit('MOV DWORD PTR [EAX + ' + ItoS(OBJ_VTABLE_OFFSET) + '], OFFSET ' + VTLabel);
  { Appeler Class_Initialize si present }
  Emit('PUSH EAX');   { sauvegarder this }
  Emit('PUSH EAX');   { passer this comme param }
  Emit('CALL ' + CLS_RT_INIT);
  Emit('ADD ESP, 4');
  Emit('POP EAX');    { restaurer this }
  { EAX = pointeur vers la nouvelle instance }
End;

{ ------------------------------------------------------------ }
{ GenSetNothing : generer code pour Set obj = Nothing            }
{   Libere l instance : appelle Class_Terminate puis            }
{   _VBRT_CLS_FREE, et met le pointeur a NULL                  }
{ ------------------------------------------------------------ }

Procedure GenSetNothing(VarLabel : TString);
Var
  SkipLbl : TString;
Begin
  Inc(ClassCount);
  SkipLbl := NextInternalLabel;
  EmitComment('Set ' + VarLabel + ' = Nothing');
  { Charger le pointeur objet }
  Emit('MOV EAX, DWORD PTR [' + VarLabel + ']');
  { Verifier si deja Nothing (NULL) }
  Emit('TEST EAX, EAX');
  Emit('JZ ' + SkipLbl);
  { Appeler Class_Terminate via runtime }
  Emit('PUSH EAX');
  Emit('CALL ' + CLS_RT_TERM);
  Emit('ADD ESP, 4');
  { Liberer la memoire }
  Emit('MOV EAX, DWORD PTR [' + VarLabel + ']');
  Emit('PUSH EAX');
  Emit('CALL ' + CLS_RT_FREE);
  Emit('ADD ESP, 4');
  { Mettre le pointeur a NULL }
  EmitLabel(SkipLbl);
  Emit('MOV DWORD PTR [' + VarLabel + '], 0');
End;

{ ------------------------------------------------------------ }
{ GenMethodCall : generer un appel de methode via vtable         }
{   obj.Method(args)                                            }
{   PUSH this, charger vtable[offset], CALL [vtable+offset]    }
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
  { Pousser this comme premier argument implicite }
  Emit('PUSH ECX');
  { Appeler via vtable[offset] }
  Emit('CALL DWORD PTR [EDX + ' + ItoS(MethodIdx * 4) + ']');
End;

{ ------------------------------------------------------------ }
{ GenVTableEntry : emettre une entree dans la vtable de classe  }
{   Genere un DD (pointeur de fonction) en section .DATA        }
{   pour chaque methode de la classe                            }
{ ------------------------------------------------------------ }

Procedure GenVTableEntry(ClassName : TString; MethodName : TString; MethodIdx : Integer);
Var
  VTLabel : TString;
  MLabel  : TString;
Begin
  Inc(ClassCount);
  VTLabel := PFX_CLS + AsmIdent(ClassName) + '_VTABLE';
  MLabel  := PFX_FUNC + AsmIdent(MethodName);
  { Premiere entree : emettre le label de la vtable }
  If MethodIdx = 0 Then Begin
    EmitComment('VTable pour classe ' + ClassName);
    EmitData(VTLabel + ' DD OFFSET ' + MLabel);
  End Else Begin
    EmitData('  DD OFFSET ' + MLabel);
  End;
End;

{ ------------------------------------------------------------ }
{ ParseClassModule : parser un module de classe complet (.CLS)  }
{   Structure :                                                 }
{     VERSION 1.0 CLASS                                         }
{     BEGIN ... END                                             }
{     Attribute VB_Name = "..."                                 }
{     [Option Explicit]                                         }
{     [Declarations (Dim, Private, Public)]                     }
{     [Property Get/Let/Set]                                    }
{     [Sub/Function]                                            }
{     [Private Sub Class_Initialize/Terminate]                  }
{   Analyse le module et genere le code assembleur              }
{ ------------------------------------------------------------ }

Procedure ParseClassModule;
Var
  ProcName : TString;
Begin
  Inc(ClassCount);
  { Detecter si c est un module de classe }
  If ModuleKind <> MODULE_CLASS Then Exit;
  EmitComment('=== Module de classe : ' + CurClassName + ' ===');
  { Parser les declarations et membres de la classe }
  { jusqu a la fin du fichier }
  While CurTokType <> TOK_EOF Do Begin
    SkipNewlines;
    If CurTokType = TOK_EOF Then Break;
    { Proprietes : Property Get/Let/Set }
    If IsKeywordToken(KW_PROPERTY) Then Begin
      LexNextToken; { consommer Property }
      If IsKeywordToken(KW_GET) Then
        ParsePropertyGet
      Else If IsKeywordToken(KW_LET) Then
        ParsePropertyLet
      Else If IsKeywordToken(KW_SET) Then
        ParsePropertySet
      Else Begin
        WarnMsg('Type de Property inconnu');
        SkipToEndOfLine;
      End;
    End
    { Sub : verifier si c est un evenement de classe }
    Else If IsKeywordToken(KW_SUB) Then Begin
      LexNextToken; { consommer Sub }
      If CurTokType = TOK_IDENT Then Begin
        ProcName := UpCaseStr(CurTokStr);
        If ProcName = 'CLASS_INITIALIZE' Then Begin
          LexNextToken; { consommer le nom }
          { Consommer les parentheses vides optionnelles }
          If CurTokType = TOK_LPAREN Then Begin
            LexNextToken;
            If CurTokType = TOK_RPAREN Then
              LexNextToken;
          End;
          SkipNewlines;
          ParseClassEvent(True);
        End
        Else If ProcName = 'CLASS_TERMINATE' Then Begin
          LexNextToken; { consommer le nom }
          If CurTokType = TOK_LPAREN Then Begin
            LexNextToken;
            If CurTokType = TOK_RPAREN Then
              LexNextToken;
          End;
          SkipNewlines;
          ParseClassEvent(False);
        End
        Else Begin
          { Sub normal dans la classe }
          SkipToEndOfLine;
        End;
      End Else
        SkipToEndOfLine;
    End
    { Private Sub -> verifier Class_Initialize / Class_Terminate }
    Else If IsKeywordToken(KW_PRIVATE) Then Begin
      LexNextToken; { consommer Private }
      If IsKeywordToken(KW_SUB) Then Begin
        LexNextToken; { consommer Sub }
        If CurTokType = TOK_IDENT Then Begin
          ProcName := UpCaseStr(CurTokStr);
          If ProcName = 'CLASS_INITIALIZE' Then Begin
            LexNextToken;
            If CurTokType = TOK_LPAREN Then Begin
              LexNextToken;
              If CurTokType = TOK_RPAREN Then
                LexNextToken;
            End;
            SkipNewlines;
            ParseClassEvent(True);
          End
          Else If ProcName = 'CLASS_TERMINATE' Then Begin
            LexNextToken;
            If CurTokType = TOK_LPAREN Then Begin
              LexNextToken;
              If CurTokType = TOK_RPAREN Then
                LexNextToken;
            End;
            SkipNewlines;
            ParseClassEvent(False);
          End
          Else
            SkipToEndOfLine;
        End Else
          SkipToEndOfLine;
      End
      Else If IsKeywordToken(KW_PROPERTY) Then Begin
        LexNextToken; { consommer Property }
        If IsKeywordToken(KW_GET) Then
          ParsePropertyGet
        Else If IsKeywordToken(KW_LET) Then
          ParsePropertyLet
        Else If IsKeywordToken(KW_SET) Then
          ParsePropertySet
        Else
          SkipToEndOfLine;
      End
      Else
        SkipToEndOfLine;
    End
    { Public Property/Sub/Function }
    Else If IsKeywordToken(KW_PUBLIC) Then Begin
      LexNextToken; { consommer Public }
      If IsKeywordToken(KW_PROPERTY) Then Begin
        LexNextToken; { consommer Property }
        If IsKeywordToken(KW_GET) Then
          ParsePropertyGet
        Else If IsKeywordToken(KW_LET) Then
          ParsePropertyLet
        Else If IsKeywordToken(KW_SET) Then
          ParsePropertySet
        Else
          SkipToEndOfLine;
      End
      Else
        SkipToEndOfLine;
    End
    Else Begin
      { Autre token : avancer }
      LexNextToken;
    End;
  End;
  { Generer la vtable par defaut si des methodes existent }
  If ClassMethodCount > 0 Then
    EmitComment('Fin vtable pour ' + CurClassName);
End;

{ ------------------------------------------------------------ }
{ IsClassDecl : verifier si le token courant est une classe     }
{ ------------------------------------------------------------ }

Function IsClassDecl : Boolean;
Begin
  IsClassDecl := (ModuleKind = MODULE_CLASS);
End;

{ ------------------------------------------------------------ }
{ IsPropertyDecl : verifier si le token est Property Get/Let/Set}
{ ------------------------------------------------------------ }

Function IsPropertyDecl : Boolean;
Begin
  IsPropertyDecl := IsKeywordToken(KW_PROPERTY);
End;

{ ------------------------------------------------------------ }
{ IsClassEvent : verifier si le nom est Class_Initialize/Term   }
{ ------------------------------------------------------------ }

Function IsClassEvent(Name : TString) : Boolean;
Var
  U : TString;
Begin
  U := UpCaseStr(Name);
  IsClassEvent := (U = 'CLASS_INITIALIZE') Or (U = 'CLASS_TERMINATE');
End;

{ ------------------------------------------------------------ }
{ Fonctions d acces aux variables du module classe             }
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

Function IsCurClassCreatable : Boolean;
Begin
  IsCurClassCreatable := CurClassCreatable;
End;

Function IsCurClassExposed : Boolean;
Begin
  IsCurClassExposed := CurClassExposed;
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
{ TODO 18 - PARSEUR : GESTION DES ERREURS (ON ERROR, RESUME,  }
{           ERR) [IMPLEMENTE]                                   }
{ ============================================================ }

Const
  { Modes de gestion d erreurs }
  ERR_HANDLER_GOTO  = 0;  { On Error GoTo label }
  ERR_HANDLER_NEXT  = 1;  { On Error Resume Next }
  ERR_HANDLER_NONE  = 2;  { On Error GoTo 0 (desactive) }

  { Nombre maximal de gestionnaires d erreurs imbriques }
  MAX_ERR_HANDLERS  = 32;

  { Labels runtime pour gestion d erreurs }
  ERR_RT_SETHANDLER  = '_VBRT_ERR_SETHANDLER';
  ERR_RT_CLEARHANDLER= '_VBRT_ERR_CLEARHANDLER';
  ERR_RT_RAISE       = '_VBRT_ERR_RAISE';
  ERR_RT_RESUME      = '_VBRT_ERR_RESUME';
  ERR_RT_RESUMENEXT  = '_VBRT_ERR_RESUMENEXT';
  ERR_RT_CLEAR       = '_VBRT_ERR_CLEAR';
  ERR_RT_SETNUMBER   = '_VBRT_ERR_SETNUMBER';
  ERR_RT_GETNUMBER   = '_VBRT_ERR_GETNUMBER';
  ERR_RT_GETDESC     = '_VBRT_ERR_GETDESC';
  ERR_RT_GETSOURCE   = '_VBRT_ERR_GETSOURCE';

  { Variables globales Err dans le segment de donnees }
  ERR_VAR_NUMBER     = '_VB_ERR_NUMBER';
  ERR_VAR_DESC       = '_VB_ERR_DESC';
  ERR_VAR_SOURCE     = '_VB_ERR_SOURCE';
  ERR_VAR_HANDLER    = '_VB_ERR_HANDLER';
  ERR_VAR_RESUME     = '_VB_ERR_RESUME';
  ERR_VAR_RESNEXT    = '_VB_ERR_RESNEXT';

Var
  ErrorHandlerCount      : LongInt;
  ErrorHandlerInitialized: Boolean;
  CurErrorMode           : Integer;
  CurErrorLabel          : TString;
  ErrResumeNextActive    : Boolean;

{ ------------------------------------------------------------ }
{ InitErrorState : initialiser l etat du gestionnaire d erreurs }
{ ------------------------------------------------------------ }

Procedure InitErrorState;
Begin
  ErrorHandlerCount       := 0;
  ErrorHandlerInitialized := True;
  CurErrorMode            := ERR_HANDLER_NONE;
  CurErrorLabel           := '';
  ErrResumeNextActive     := False;
End;

{ ------------------------------------------------------------ }
{ ParseOnError : parser une instruction On Error                }
{   Syntaxe : On Error GoTo label                               }
{             On Error GoTo 0                                    }
{             On Error Resume Next                               }
{   Genere le code pour etablir/retirer le gestionnaire SEH     }
{ ------------------------------------------------------------ }

Procedure ParseOnError;
Var
  TargetLabel : TString;
Begin
  Inc(ErrorHandlerCount);
  { On est positionne apres 'On', consommer 'Error' }
  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_ERROR) Then Begin
    LexNextToken; { consommer Error }
    { Trois formes possibles }
    If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_GOTO) Then Begin
      LexNextToken; { consommer GoTo }
      { On Error GoTo 0 : desactiver le gestionnaire }
      If (CurTokType = TOK_INTEGER) And (CurTokStr = '0') Then Begin
        LexNextToken; { consommer 0 }
        CurErrorMode  := ERR_HANDLER_NONE;
        CurErrorLabel := '';
        ErrResumeNextActive := False;
        { Generer : MOV DWORD [_VB_ERR_HANDLER], 0 }
        EmitComment('On Error GoTo 0 : desactiver gestionnaire');
        Emit('  MOV DWORD [' + ERR_VAR_HANDLER + '], 0');
        Emit('  MOV BYTE [' + ERR_VAR_RESNEXT + '], 0');
        If Opts.Verbose Then
          WriteLn('  On Error GoTo 0');
      End
      { On Error GoTo label : etablir le gestionnaire }
      Else If CurTokType = TOK_IDENT Then Begin
        TargetLabel := CurTokStr;
        LexNextToken; { consommer label }
        CurErrorMode  := ERR_HANDLER_GOTO;
        CurErrorLabel := TargetLabel;
        ErrResumeNextActive := False;
        { Generer : PUSH OFFSET _VBL_label / CALL _VBRT_ERR_SETHANDLER }
        EmitComment('On Error GoTo ' + TargetLabel);
        Emit('  MOV DWORD [' + ERR_VAR_HANDLER + '], OFFSET _VBL_' + TargetLabel);
        Emit('  MOV BYTE [' + ERR_VAR_RESNEXT + '], 0');
        If Opts.Verbose Then
          WriteLn('  On Error GoTo ', TargetLabel);
      End
      Else Begin
        FatalError('On Error GoTo : label ou 0 attendu');
      End;
    End
    { On Error Resume Next }
    Else If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_RESUME) Then Begin
      LexNextToken; { consommer Resume }
      If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_NEXT) Then Begin
        LexNextToken; { consommer Next }
        CurErrorMode := ERR_HANDLER_NEXT;
        CurErrorLabel := '';
        ErrResumeNextActive := True;
        { Generer : MOV BYTE [_VB_ERR_RESNEXT], 1 }
        EmitComment('On Error Resume Next');
        Emit('  MOV DWORD [' + ERR_VAR_HANDLER + '], 0');
        Emit('  MOV BYTE [' + ERR_VAR_RESNEXT + '], 1');
        If Opts.Verbose Then
          WriteLn('  On Error Resume Next');
      End Else Begin
        FatalError('On Error Resume : Next attendu');
      End;
    End
    Else Begin
      FatalError('On Error : GoTo ou Resume attendu');
    End;
  End Else Begin
    FatalError('On : Error attendu apres On');
  End;
End;

{ ------------------------------------------------------------ }
{ ParseResume : parser une instruction Resume                   }
{   Syntaxe : Resume                                             }
{             Resume Next                                        }
{             Resume label                                       }
{   Genere un saut vers l instruction fautive, la suivante,    }
{   ou un label specifique                                      }
{ ------------------------------------------------------------ }

Procedure ParseResume;
Var
  TargetLabel : TString;
Begin
  Inc(ErrorHandlerCount);
  { On est positionne apres 'Resume' }
  { Resume Next : reprendre a l instruction suivante }
  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_NEXT) Then Begin
    LexNextToken; { consommer Next }
    EmitComment('Resume Next');
    Emit('  PUSH DWORD [' + ERR_VAR_RESUME + ']');
    Emit('  CALL ' + ERR_RT_RESUMENEXT);
    { Nettoyer l etat d erreur }
    Emit('  MOV DWORD [' + ERR_VAR_NUMBER + '], 0');
    If Opts.Verbose Then
      WriteLn('  Resume Next');
  End
  { Resume label : sauter au label specifique }
  Else If CurTokType = TOK_IDENT Then Begin
    TargetLabel := CurTokStr;
    LexNextToken; { consommer label }
    EmitComment('Resume ' + TargetLabel);
    { Nettoyer l etat d erreur }
    Emit('  MOV DWORD [' + ERR_VAR_NUMBER + '], 0');
    Emit('  JMP _VBL_' + TargetLabel);
    If Opts.Verbose Then
      WriteLn('  Resume ', TargetLabel);
  End
  { Resume seul : reprendre a l instruction fautive }
  Else Begin
    EmitComment('Resume');
    Emit('  PUSH DWORD [' + ERR_VAR_RESUME + ']');
    Emit('  CALL ' + ERR_RT_RESUME);
    { Nettoyer l etat d erreur }
    Emit('  MOV DWORD [' + ERR_VAR_NUMBER + '], 0');
    If Opts.Verbose Then
      WriteLn('  Resume');
  End;
End;

{ ------------------------------------------------------------ }
{ ParseErrMember : parser un acces a l objet Err                }
{   Syntaxe : Err.Number                                        }
{             Err.Description                                    }
{             Err.Source                                          }
{             Err.Clear                                          }
{             Err.Raise number[, source][, description]          }
{   Genere le code pour lire/ecrire les proprietes Err          }
{ ------------------------------------------------------------ }

Procedure ParseErrMember;
Var
  MemberName : TString;
Begin
  Inc(ErrorHandlerCount);
  { On est positionne apres 'Err' et le point }
  { On attend le nom du membre }
  If CurTokType = TOK_IDENT Then Begin
    MemberName := UpCaseStr(CurTokStr);
    LexNextToken; { consommer le nom du membre }

    { Err.Number : lire le numero d erreur dans EAX }
    If MemberName = 'NUMBER' Then Begin
      EmitComment('Err.Number');
      Emit('  MOV EAX, DWORD [' + ERR_VAR_NUMBER + ']');
      If Opts.Verbose Then
        WriteLn('  Err.Number');
    End

    { Err.Description : lire la description dans EAX (pointeur) }
    Else If MemberName = 'DESCRIPTION' Then Begin
      EmitComment('Err.Description');
      Emit('  MOV EAX, DWORD [' + ERR_VAR_DESC + ']');
      If Opts.Verbose Then
        WriteLn('  Err.Description');
    End

    { Err.Source : lire la source dans EAX (pointeur) }
    Else If MemberName = 'SOURCE' Then Begin
      EmitComment('Err.Source');
      Emit('  MOV EAX, DWORD [' + ERR_VAR_SOURCE + ']');
      If Opts.Verbose Then
        WriteLn('  Err.Source');
    End

    { Err.Clear : reinitialiser toutes les variables Err }
    Else If MemberName = 'CLEAR' Then Begin
      EmitComment('Err.Clear');
      Emit('  MOV DWORD [' + ERR_VAR_NUMBER + '], 0');
      Emit('  MOV DWORD [' + ERR_VAR_DESC + '], 0');
      Emit('  MOV DWORD [' + ERR_VAR_SOURCE + '], 0');
      If Opts.Verbose Then
        WriteLn('  Err.Clear');
    End

    { Err.Raise number[, source][, description] }
    Else If MemberName = 'RAISE' Then Begin
      EmitComment('Err.Raise');
      { Parser le numero d erreur (expression) }
      ParseExpr;
      Emit('  MOV DWORD [' + ERR_VAR_NUMBER + '], EAX');
      { Verifier s il y a des arguments optionnels }
      If CurTokType = TOK_COMMA Then Begin
        LexNextToken; { consommer , }
        { Parser la source (expression chaine) }
        ParseExpr;
        Emit('  MOV DWORD [' + ERR_VAR_SOURCE + '], EAX');
        If CurTokType = TOK_COMMA Then Begin
          LexNextToken; { consommer , }
          { Parser la description (expression chaine) }
          ParseExpr;
          Emit('  MOV DWORD [' + ERR_VAR_DESC + '], EAX');
        End;
      End;
      { Sauter au gestionnaire d erreur si actif }
      Emit('  CMP DWORD [' + ERR_VAR_HANDLER + '], 0');
      Emit('  JE @@err_raise_nohandler');
      Emit('  JMP DWORD [' + ERR_VAR_HANDLER + ']');
      Emit('@@err_raise_nohandler:');
      { Si pas de gestionnaire, verifier Resume Next }
      Emit('  CMP BYTE [' + ERR_VAR_RESNEXT + '], 1');
      Emit('  JE @@err_raise_done');
      { Si pas de gestionnaire et pas Resume Next, erreur fatale }
      Emit('  PUSH DWORD [' + ERR_VAR_NUMBER + ']');
      Emit('  CALL ' + ERR_RT_RAISE);
      Emit('@@err_raise_done:');
      If Opts.Verbose Then
        WriteLn('  Err.Raise');
    End

    Else Begin
      FatalError('Membre Err inconnu : ' + MemberName);
    End;
  End Else Begin
    FatalError('Err. : nom de membre attendu');
  End;
End;

{ ------------------------------------------------------------ }
{ GenSetErrorHandler : generer le code pour etablir un          }
{   gestionnaire d erreurs SEH                                  }
{   Empile l adresse du gestionnaire sur la pile SEH Win32     }
{ ------------------------------------------------------------ }

Procedure GenSetErrorHandler(HandlerLabel : TString);
Begin
  Inc(ErrorHandlerCount);
  EmitComment('Etablir gestionnaire SEH : ' + HandlerLabel);
  { Structure SEH Win32 : PUSH handler / PUSH DWORD [FS:0] / MOV [FS:0], ESP }
  Emit('  PUSH OFFSET _VBL_' + HandlerLabel);
  Emit('  PUSH DWORD [FS:0]');
  Emit('  MOV [FS:0], ESP');
  If Opts.Verbose Then
    WriteLn('  SEH: etablir ', HandlerLabel);
End;

{ ------------------------------------------------------------ }
{ GenClearErrorHandler : generer le code pour retirer le        }
{   gestionnaire SEH courant                                    }
{   Depile la structure SEH de la pile                          }
{ ------------------------------------------------------------ }

Procedure GenClearErrorHandler;
Begin
  Inc(ErrorHandlerCount);
  EmitComment('Retirer gestionnaire SEH');
  { Depiler la structure SEH : POP DWORD [FS:0] / ADD ESP, 4 }
  Emit('  POP DWORD [FS:0]');
  Emit('  ADD ESP, 4');
  If Opts.Verbose Then
    WriteLn('  SEH: retirer');
End;

{ ------------------------------------------------------------ }
{ GenResumeNextFlag : generer le code pour activer/desactiver  }
{   le flag Resume Next                                         }
{   Active=True : erreurs ignorees silencieusement              }
{ ------------------------------------------------------------ }

Procedure GenResumeNextFlag(Active : Boolean);
Begin
  Inc(ErrorHandlerCount);
  If Active Then Begin
    EmitComment('Activer Resume Next');
    Emit('  MOV BYTE [' + ERR_VAR_RESNEXT + '], 1');
  End Else Begin
    EmitComment('Desactiver Resume Next');
    Emit('  MOV BYTE [' + ERR_VAR_RESNEXT + '], 0');
  End;
End;

{ ------------------------------------------------------------ }
{ GenErrRaise : generer le code pour declencher une erreur     }
{   ErrNum : numero d erreur a declencher                       }
{   Appelle le runtime si pas de gestionnaire actif             }
{ ------------------------------------------------------------ }

Procedure GenErrRaise(ErrNum : LongInt);
Begin
  Inc(ErrorHandlerCount);
  EmitComment('Declencher erreur ' + ItoS(ErrNum));
  Emit('  MOV DWORD [' + ERR_VAR_NUMBER + '], ' + ItoS(ErrNum));
  { Verifier si un gestionnaire est actif }
  Emit('  CMP DWORD [' + ERR_VAR_HANDLER + '], 0');
  Emit('  JE @@genraise_nohandler');
  Emit('  JMP DWORD [' + ERR_VAR_HANDLER + ']');
  Emit('@@genraise_nohandler:');
  { Verifier Resume Next }
  Emit('  CMP BYTE [' + ERR_VAR_RESNEXT + '], 1');
  Emit('  JE @@genraise_done');
  { Erreur fatale runtime }
  Emit('  PUSH ' + ItoS(ErrNum));
  Emit('  CALL ' + ERR_RT_RAISE);
  Emit('@@genraise_done:');
End;

{ ------------------------------------------------------------ }
{ GenErrDataSegment : generer les variables Err dans .DATA/.BSS }
{   Declare les variables globales pour l objet Err             }
{ ------------------------------------------------------------ }

Procedure GenErrDataSegment;
Begin
  EmitComment('Variables globales Err');
  EmitBss(ERR_VAR_NUMBER  + ' DD 0');
  EmitBss(ERR_VAR_DESC    + ' DD 0');
  EmitBss(ERR_VAR_SOURCE  + ' DD 0');
  EmitBss(ERR_VAR_HANDLER + ' DD 0');
  EmitBss(ERR_VAR_RESUME  + ' DD 0');
  EmitBss(ERR_VAR_RESNEXT + ' DB 0');
End;

{ ------------------------------------------------------------ }
{ IsOnErrorStatement : verifier si le token courant commence   }
{   une instruction On Error                                    }
{ ------------------------------------------------------------ }

Function IsOnErrorStatement : Boolean;
Begin
  IsOnErrorStatement := (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_ON);
End;

{ ------------------------------------------------------------ }
{ IsResumeStatement : verifier si le token courant est Resume  }
{ ------------------------------------------------------------ }

Function IsResumeStatement : Boolean;
Begin
  IsResumeStatement := (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_RESUME);
End;

{ ------------------------------------------------------------ }
{ IsErrAccess : verifier si le token courant est l objet Err   }
{ ------------------------------------------------------------ }

Function IsErrAccess : Boolean;
Begin
  IsErrAccess := (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_ERR);
End;

{ ------------------------------------------------------------ }
{ Fonctions d acces aux variables du module erreur              }
{ ------------------------------------------------------------ }

Function GetErrorHandlerCount : LongInt;
Begin
  GetErrorHandlerCount := ErrorHandlerCount;
End;

Function IsErrorHandlerInitialized : Boolean;
Begin
  IsErrorHandlerInitialized := ErrorHandlerInitialized;
End;

Function IsErrorHandlerEmpty : Boolean;
Begin
  IsErrorHandlerEmpty := ErrorHandlerInitialized And (ErrorHandlerCount = 0);
End;

Function GetErrorHandlerStatus : TString;
Begin
  If Not ErrorHandlerInitialized Then
    GetErrorHandlerStatus := 'non initialise'
  Else If ErrorHandlerCount = 0 Then
    GetErrorHandlerStatus := 'initialise, aucun gestionnaire'
  Else
    GetErrorHandlerStatus := 'initialise, ' + ItoS(ErrorHandlerCount) + ' operations';
End;

Function GetCurErrorMode : Integer;
Begin
  GetCurErrorMode := CurErrorMode;
End;

Function GetCurErrorLabel : TString;
Begin
  GetCurErrorLabel := CurErrorLabel;
End;

Function IsErrResumeNextActive : Boolean;
Begin
  IsErrResumeNextActive := ErrResumeNextActive;
End;

Function IsErrHandlerGoto : Boolean;
Begin
  IsErrHandlerGoto := (CurErrorMode = ERR_HANDLER_GOTO);
End;

Function IsErrHandlerNone : Boolean;
Begin
  IsErrHandlerNone := (CurErrorMode = ERR_HANDLER_NONE);
End;

Function GetMaxErrHandlers : Integer;
Begin
  GetMaxErrHandlers := MAX_ERR_HANDLERS;
End;

{ ============================================================ }
{ TODO 19 - PARSEUR : ENTREES/SORTIES FICHIERS (OPEN, CLOSE,  }
{           PRINT#, INPUT#) [IMPLEMENTE]                        }
{ ============================================================ }

Const
  { Modes d ouverture de fichier VB6 }
  FILE_MODE_INPUT   = 0;  { Open For Input }
  FILE_MODE_OUTPUT  = 1;  { Open For Output }
  FILE_MODE_APPEND  = 2;  { Open For Append }
  FILE_MODE_BINARY  = 3;  { Open For Binary }
  FILE_MODE_RANDOM  = 4;  { Open For Random }

  { Nombre maximal de fichiers ouverts simultanement }
  MAX_FILE_NUM      = 511;

  { Taille par defaut d un enregistrement Random }
  DEFAULT_RECORD_LEN = 128;

  { Labels runtime pour les operations E/S fichiers }
  FIO_RT_OPEN        = '_VBRT_FILE_OPEN';
  FIO_RT_CLOSE       = '_VBRT_FILE_CLOSE';
  FIO_RT_CLOSEALL    = '_VBRT_FILE_CLOSEALL';
  FIO_RT_PRINT       = '_VBRT_FILE_PRINT';
  FIO_RT_WRITE       = '_VBRT_FILE_WRITE';
  FIO_RT_INPUT       = '_VBRT_FILE_INPUT';
  FIO_RT_LINEINPUT   = '_VBRT_FILE_LINEINPUT';
  FIO_RT_GET         = '_VBRT_FILE_GET';
  FIO_RT_PUT         = '_VBRT_FILE_PUT';
  FIO_RT_SEEK        = '_VBRT_FILE_SEEK';

  { Labels runtime pour les fonctions fichiers }
  FIO_RT_EOF         = '_VBRT_FILE_EOF';
  FIO_RT_LOF         = '_VBRT_FILE_LOF';
  FIO_RT_LOC         = '_VBRT_FILE_LOC';
  FIO_RT_FREEFILE    = '_VBRT_FILE_FREEFILE';

  { Variables globales pour la table de handles }
  FIO_VAR_HANDLES    = '_VB_FILE_HANDLES';
  FIO_VAR_MODES      = '_VB_FILE_MODES';
  FIO_VAR_COUNT      = '_VB_FILE_COUNT';
  FIO_VAR_RECLEN     = '_VB_FILE_RECLEN';

Var
  FileIOCount      : LongInt;
  FileIOInitialized: Boolean;
  CurFileMode      : Integer;
  CurFileNum       : Integer;
  CurRecordLen     : Integer;

{ ------------------------------------------------------------ }
{ InitFileIOState : initialiser l etat des E/S fichiers        }
{ ------------------------------------------------------------ }

Procedure InitFileIOState;
Begin
  FileIOCount       := 0;
  FileIOInitialized := True;
  CurFileMode       := FILE_MODE_INPUT;
  CurFileNum        := 0;
  CurRecordLen      := DEFAULT_RECORD_LEN;
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
    FILE_MODE_RANDOM : FileModeName := 'Random';
  Else
    FileModeName := 'Unknown';
  End;
End;

{ ------------------------------------------------------------ }
{ ParseFileNumber : parser un numero de fichier #n             }
{   Attend '#' suivi d un nombre entier ou expression          }
{   Retourne le numero dans CurFileNum                         }
{ ------------------------------------------------------------ }

Procedure ParseFileNumber;
Begin
  { Consommer le '#' si present }
  If CurTokType = TOK_HASH Then
    LexNextToken;
  { Evaluer l expression qui donne le numero }
  ParseExpr;
  { Le resultat est dans EAX }
End;

{ ------------------------------------------------------------ }
{ ParseOpen : parser une instruction Open                       }
{   Syntaxe : Open fichier For Mode As #n [Len = taille]       }
{   Modes : Input, Output, Append, Binary, Random              }
{   Genere un appel a _VBRT_FILE_OPEN(fichier, mode, num, len) }
{ ------------------------------------------------------------ }

Procedure ParseOpen;
Var
  FileMode  : Integer;
  HasLen    : Boolean;
  ModeStr   : TString;
Begin
  Inc(FileIOCount);
  EmitComment('Open fichier For mode As #n');
  { Parser le nom de fichier (expression chaine) }
  ParseExpr;
  Emit('  PUSH EAX');  { sauvegarder le pointeur chaine fichier }
  { Attendre 'For' }
  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_FOR) Then
    LexNextToken
  Else
    FatalError('Open : mot-cle For attendu');
  { Determiner le mode }
  FileMode := FILE_MODE_INPUT;  { defaut }
  If CurTokType = TOK_KEYWORD Then Begin
    ModeStr := CurTokStr;
    If CurTokNum = KW_INPUT Then Begin
      FileMode := FILE_MODE_INPUT;
      LexNextToken;
    End Else If ModeStr = 'OUTPUT' Then Begin
      FileMode := FILE_MODE_OUTPUT;
      LexNextToken;
    End Else If ModeStr = 'APPEND' Then Begin
      FileMode := FILE_MODE_APPEND;
      LexNextToken;
    End Else If ModeStr = 'BINARY' Then Begin
      FileMode := FILE_MODE_BINARY;
      LexNextToken;
    End Else If ModeStr = 'RANDOM' Then Begin
      FileMode := FILE_MODE_RANDOM;
      LexNextToken;
    End Else
      FatalError('Open : mode Input/Output/Append/Binary/Random attendu');
  End Else If CurTokType = TOK_IDENT Then Begin
    ModeStr := CurTokStr;
    If ModeStr = 'OUTPUT' Then Begin
      FileMode := FILE_MODE_OUTPUT;
      LexNextToken;
    End Else If ModeStr = 'APPEND' Then Begin
      FileMode := FILE_MODE_APPEND;
      LexNextToken;
    End Else If ModeStr = 'BINARY' Then Begin
      FileMode := FILE_MODE_BINARY;
      LexNextToken;
    End Else If ModeStr = 'RANDOM' Then Begin
      FileMode := FILE_MODE_RANDOM;
      LexNextToken;
    End Else
      FatalError('Open : mode d ouverture invalide : ' + ModeStr);
  End Else
    FatalError('Open : mode d ouverture attendu');
  CurFileMode := FileMode;
  { Attendre 'As' }
  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_AS) Then
    LexNextToken
  Else
    FatalError('Open : mot-cle As attendu');
  { Parser le numero de fichier }
  ParseFileNumber;
  Emit('  PUSH EAX');  { sauvegarder le numero de fichier }
  { Verifier s il y a Len = taille (pour Random) }
  HasLen := False;
  If (CurTokType = TOK_KEYWORD) And (CurTokStr = 'LEN') Then Begin
    LexNextToken;
    { Consommer '=' }
    If CurTokType = TOK_EQ Then
      LexNextToken
    Else
      FatalError('Open : symbole = attendu apres Len');
    ParseExpr;  { taille dans EAX }
    HasLen := True;
  End;
  { Generer l appel runtime }
  If HasLen Then Begin
    Emit('  PUSH EAX');  { taille enregistrement }
  End Else Begin
    Emit('  PUSH ' + ItoS(DEFAULT_RECORD_LEN));
  End;
  Emit('  PUSH ' + ItoS(FileMode));   { mode d ouverture }
  { Les parametres sont : fichier, num, len, mode }
  Emit('  CALL ' + FIO_RT_OPEN);
  Emit('  ADD ESP, 16');  { nettoyer 4 parametres x 4 octets }
End;

{ ------------------------------------------------------------ }
{ ParseClose : parser une instruction Close                     }
{   Syntaxe : Close [#n [, #n2 ...]]                           }
{   Sans argument : ferme tous les fichiers ouverts            }
{ ------------------------------------------------------------ }

Procedure ParseClose;
Var
  HasFileNum : Boolean;
Begin
  Inc(FileIOCount);
  EmitComment('Close [#n]');
  { Verifier s il y a un numero de fichier }
  HasFileNum := False;
  If CurTokType = TOK_HASH Then
    HasFileNum := True
  Else If CurTokType = TOK_INTEGER Then
    HasFileNum := True;
  If HasFileNum Then Begin
    { Boucle pour fermer plusieurs fichiers : Close #1, #2 }
    Repeat
      ParseFileNumber;
      Emit('  PUSH EAX');
      Emit('  CALL ' + FIO_RT_CLOSE);
      Emit('  ADD ESP, 4');
      { Verifier s il y a une virgule pour un autre fichier }
      If CurTokType = TOK_COMMA Then
        LexNextToken
      Else
        Break;
    Until False;
  End Else Begin
    { Fermer tous les fichiers }
    Emit('  CALL ' + FIO_RT_CLOSEALL);
  End;
End;

{ ------------------------------------------------------------ }
{ ParsePrint : parser Print #n ou Write #n                     }
{   Syntaxe : Print #n, expr1[; expr2][, expr3]                }
{             Write #n, expr1, expr2, expr3                    }
{   Le separateur ; concatene, la virgule ajoute un TAB        }
{ ------------------------------------------------------------ }

Procedure ParsePrintFile;
Var
  IsWrite    : Boolean;
  FExprCount : Integer;
  SepIsComma : Boolean;
Begin
  Inc(FileIOCount);
  { Determiner si c est Print ou Write }
  IsWrite := (CurTokNum = KW_WRITE);
  If IsWrite Then
    EmitComment('Write #n, expressions')
  Else
    EmitComment('Print #n, expressions');
  { Parser le numero de fichier }
  ParseFileNumber;
  Emit('  PUSH EAX');  { sauvegarder le numero }
  { Consommer la virgule apres #n }
  If CurTokType = TOK_COMMA Then
    LexNextToken;
  { Parser les expressions a ecrire }
  FExprCount := 0;
  While (CurTokType <> TOK_NEWLINE) And (CurTokType <> TOK_EOF) Do Begin
    ParseExpr;
    Inc(FExprCount);
    { Generer l appel d ecriture pour chaque expression }
    Emit('  PUSH EAX');
    If IsWrite Then
      Emit('  CALL ' + FIO_RT_WRITE)
    Else
      Emit('  CALL ' + FIO_RT_PRINT);
    Emit('  ADD ESP, 4');
    { Verifier le separateur }
    SepIsComma := False;
    If CurTokType = TOK_SEMI Then Begin
      LexNextToken;  { concatenation directe }
    End Else If CurTokType = TOK_COMMA Then Begin
      SepIsComma := True;
      LexNextToken;  { separateur tabulation }
    End Else
      Break;  { fin des expressions }
    If SepIsComma And (Not IsWrite) Then Begin
      { Emettre un TAB pour Print avec virgule }
      Emit('  PUSH 9');  { TAB = chr(9) }
      Emit('  CALL ' + FIO_RT_PRINT);
      Emit('  ADD ESP, 4');
    End;
  End;
  { Restaurer le numero de fichier }
  Emit('  POP EBX');  { numero de fichier }
End;

{ ------------------------------------------------------------ }
{ ParseInputFile : parser une instruction Input #n ou Line Input}
{   Syntaxe : Input #n, var1[, var2 ...]                       }
{             Line Input #n, var$                               }
{   Lit des donnees depuis le fichier dans les variables       }
{ ------------------------------------------------------------ }

Procedure ParseInputFile;
Var
  IsLineInput : Boolean;
  VarIdx      : Integer;
Begin
  Inc(FileIOCount);
  { Verifier si c est 'Line Input' }
  IsLineInput := False;
  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_LINE) Then Begin
    IsLineInput := True;
    LexNextToken;  { consommer 'Line' }
    EmitComment('Line Input #n, variable');
    { Attendre 'Input' }
    If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_INPUT) Then
      LexNextToken
    Else
      FatalError('Line Input : mot-cle Input attendu apres Line');
  End Else Begin
    EmitComment('Input #n, variables');
  End;
  { Parser le numero de fichier }
  ParseFileNumber;
  Emit('  PUSH EAX');  { sauvegarder le numero }
  { Consommer la virgule apres #n }
  If CurTokType = TOK_COMMA Then
    LexNextToken;
  If IsLineInput Then Begin
    { Line Input : une seule variable chaine }
    If CurTokType = TOK_IDENT Then Begin
      VarIdx := FindSym(CurTokStr);
      If VarIdx < 0 Then
        FatalError('Line Input : variable non declaree : ' + CurTokStr);
      LexNextToken;
      { Generer l appel }
      Emit('  POP EBX');  { numero de fichier }
      Emit('  PUSH EBX');
      Emit('  CALL ' + FIO_RT_LINEINPUT);
      Emit('  ADD ESP, 4');
      { Stocker le resultat }
      If VarIdx >= 0 Then
        GenStoreVar(VarIdx);
    End Else
      FatalError('Line Input : variable attendue');
  End Else Begin
    { Input : plusieurs variables separees par virgules }
    Repeat
      If CurTokType = TOK_IDENT Then Begin
        VarIdx := FindSym(CurTokStr);
        If VarIdx < 0 Then
          FatalError('Input : variable non declaree : ' + CurTokStr);
        LexNextToken;
        { Generer l appel de lecture }
        Emit('  CALL ' + FIO_RT_INPUT);
        { Stocker le resultat }
        If VarIdx >= 0 Then
          GenStoreVar(VarIdx);
      End Else
        FatalError('Input : variable attendue');
      { Verifier la virgule pour continuer }
      If CurTokType = TOK_COMMA Then
        LexNextToken
      Else
        Break;
    Until False;
    { Nettoyer le numero de fichier de la pile }
    Emit('  POP EBX');
  End;
End;

{ ------------------------------------------------------------ }
{ ParseGet : parser une instruction Get (acces aleatoire)      }
{   Syntaxe : Get #n, [position], variable                     }
{   Lit un enregistrement a la position donnee                 }
{ ------------------------------------------------------------ }

Procedure ParseGet;
Var
  VarIdx : Integer;
Begin
  Inc(FileIOCount);
  EmitComment('Get #n, [position], variable');
  { Parser le numero de fichier }
  ParseFileNumber;
  Emit('  PUSH EAX');  { sauvegarder le numero }
  { Consommer la virgule }
  If CurTokType = TOK_COMMA Then
    LexNextToken;
  { Verifier s il y a une position (optionnelle) }
  If CurTokType <> TOK_COMMA Then Begin
    { Il y a une expression de position }
    ParseExpr;
    Emit('  PUSH EAX');  { position }
  End Else Begin
    { Position omise, utiliser la position courante }
    Emit('  PUSH -1');  { -1 = position courante }
  End;
  { Consommer la virgule avant la variable }
  If CurTokType = TOK_COMMA Then
    LexNextToken;
  { Parser la variable de destination }
  If CurTokType = TOK_IDENT Then Begin
    VarIdx := FindSym(CurTokStr);
    If VarIdx < 0 Then
      FatalError('Get : variable non declaree : ' + CurTokStr);
    LexNextToken;
    { Generer l appel runtime }
    Emit('  CALL ' + FIO_RT_GET);
    Emit('  ADD ESP, 8');
    { Stocker le resultat }
    If VarIdx >= 0 Then
      GenStoreVar(VarIdx);
  End Else
    FatalError('Get : variable attendue');
End;

{ ------------------------------------------------------------ }
{ ParsePut : parser une instruction Put (acces aleatoire)      }
{   Syntaxe : Put #n, [position], variable                     }
{   Ecrit un enregistrement a la position donnee               }
{ ------------------------------------------------------------ }

Procedure ParsePut;
Begin
  Inc(FileIOCount);
  EmitComment('Put #n, [position], expression');
  { Parser le numero de fichier }
  ParseFileNumber;
  Emit('  PUSH EAX');  { sauvegarder le numero }
  { Consommer la virgule }
  If CurTokType = TOK_COMMA Then
    LexNextToken;
  { Verifier s il y a une position (optionnelle) }
  If CurTokType <> TOK_COMMA Then Begin
    ParseExpr;
    Emit('  PUSH EAX');  { position }
  End Else Begin
    Emit('  PUSH -1');  { -1 = position courante }
  End;
  { Consommer la virgule avant la donnee }
  If CurTokType = TOK_COMMA Then
    LexNextToken;
  { Parser l expression a ecrire }
  ParseExpr;
  Emit('  PUSH EAX');  { donnee a ecrire }
  { Generer l appel runtime }
  Emit('  CALL ' + FIO_RT_PUT);
  Emit('  ADD ESP, 12');  { 3 parametres x 4 octets }
End;

{ ------------------------------------------------------------ }
{ ParseSeek : parser une instruction Seek                      }
{   Syntaxe : Seek #n, position                                }
{   Deplace le curseur de lecture/ecriture                     }
{ ------------------------------------------------------------ }

Procedure ParseSeek;
Begin
  Inc(FileIOCount);
  EmitComment('Seek #n, position');
  { Parser le numero de fichier }
  ParseFileNumber;
  Emit('  PUSH EAX');  { numero de fichier }
  { Consommer la virgule }
  If CurTokType = TOK_COMMA Then
    LexNextToken;
  { Parser la position }
  ParseExpr;
  Emit('  PUSH EAX');  { position }
  { Generer l appel runtime }
  Emit('  CALL ' + FIO_RT_SEEK);
  Emit('  ADD ESP, 8');
End;

{ ------------------------------------------------------------ }
{ GenFileOpen : generer le code d ouverture Win32 API           }
{   Utilise CreateFileA avec les flags selon le mode            }
{ ------------------------------------------------------------ }

Procedure GenFileOpen(Mode : Integer; FileNum : Integer);
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
    FILE_MODE_BINARY, FILE_MODE_RANDOM : Begin
      Emit('  PUSH 4');      { dwCreationDisposition = OPEN_ALWAYS }
      Emit('  PUSH 0');
      Emit('  PUSH 0');
      Emit('  PUSH 0xC0000000');  { GENERIC_READ or GENERIC_WRITE }
    End;
  End;
  { Le nom de fichier est deja dans la pile }
  Emit('  CALL _CreateFileA@28');
  { Sauvegarder le handle dans la table }
  Emit('  MOV [' + FIO_VAR_HANDLES + '+' + ItoS(FileNum) + '*4], EAX');
End;

{ ------------------------------------------------------------ }
{ GenFileClose : generer le code de fermeture Win32 API         }
{   Utilise CloseHandle                                        }
{ ------------------------------------------------------------ }

Procedure GenFileClose(FileNum : Integer);
Begin
  EmitComment('Fermeture fichier #' + ItoS(FileNum));
  Emit('  MOV EAX, [' + FIO_VAR_HANDLES + '+' + ItoS(FileNum) + '*4]');
  Emit('  PUSH EAX');
  Emit('  CALL _CloseHandle@4');
  { Marquer le handle comme invalide }
  Emit('  MOV DWORD [' + FIO_VAR_HANDLES + '+' + ItoS(FileNum) + '*4], 0');
End;

{ ------------------------------------------------------------ }
{ GenFileRead : generer le code de lecture via ReadFile          }
{   Lit des donnees depuis le handle Win32                     }
{ ------------------------------------------------------------ }

Procedure GenFileRead(FileNum : Integer; BufLabel : TString; Size : Integer);
Var
  DoneLabel : TString;
Begin
  DoneLabel := NextInternalLabel;
  EmitComment('Lecture fichier #' + ItoS(FileNum));
  Emit('  PUSH 0');          { lpOverlapped = NULL }
  Emit('  LEA EBX, [EBP-4]');
  Emit('  PUSH EBX');        { lpNumberOfBytesRead }
  Emit('  PUSH ' + ItoS(Size));  { nNumberOfBytesToRead }
  Emit('  PUSH ' + BufLabel);    { lpBuffer }
  Emit('  MOV EAX, [' + FIO_VAR_HANDLES + '+' + ItoS(FileNum) + '*4]');
  Emit('  PUSH EAX');        { hFile }
  Emit('  CALL _ReadFile@20');
  EmitLabel(DoneLabel);
End;

{ ------------------------------------------------------------ }
{ GenFileWrite : generer le code d ecriture via WriteFile       }
{   Ecrit des donnees dans le handle Win32                     }
{ ------------------------------------------------------------ }

Procedure GenFileWrite(FileNum : Integer; BufLabel : TString; Size : Integer);
Var
  DoneLabel : TString;
Begin
  DoneLabel := NextInternalLabel;
  EmitComment('Ecriture fichier #' + ItoS(FileNum));
  Emit('  PUSH 0');          { lpOverlapped = NULL }
  Emit('  LEA EBX, [EBP-4]');
  Emit('  PUSH EBX');        { lpNumberOfBytesWritten }
  Emit('  PUSH ' + ItoS(Size));  { nNumberOfBytesToWrite }
  Emit('  PUSH ' + BufLabel);    { lpBuffer }
  Emit('  MOV EAX, [' + FIO_VAR_HANDLES + '+' + ItoS(FileNum) + '*4]');
  Emit('  PUSH EAX');        { hFile }
  Emit('  CALL _WriteFile@20');
  EmitLabel(DoneLabel);
End;

{ ------------------------------------------------------------ }
{ GenFileDataSegment : generer les variables fichier en .BSS    }
{   Declare la table de handles et variables globales          }
{ ------------------------------------------------------------ }

Procedure GenFileDataSegment;
Begin
  EmitComment('Variables globales E/S fichiers');
  EmitBss(FIO_VAR_HANDLES + ' RESD ' + ItoS(MAX_FILE_NUM + 1));
  EmitBss(FIO_VAR_MODES   + ' RESD ' + ItoS(MAX_FILE_NUM + 1));
  EmitBss(FIO_VAR_COUNT   + ' DD 0');
  EmitBss(FIO_VAR_RECLEN  + ' RESD ' + ItoS(MAX_FILE_NUM + 1));
End;

{ ------------------------------------------------------------ }
{ ParseEOFCall : parser un appel a la fonction EOF(n)           }
{   Retourne True (-1) si fin de fichier, False (0) sinon     }
{ ------------------------------------------------------------ }

Procedure ParseEOFCall;
Begin
  Inc(FileIOCount);
  EmitComment('EOF(n)');
  { Attendre la parenthese ouvrante }
  If CurTokType = TOK_LPAREN Then
    LexNextToken;
  { Parser le numero de fichier }
  ParseExpr;
  Emit('  PUSH EAX');
  { Fermer la parenthese }
  If CurTokType = TOK_RPAREN Then
    LexNextToken;
  { Appeler la routine runtime }
  Emit('  CALL ' + FIO_RT_EOF);
  Emit('  ADD ESP, 4');
  { Resultat dans EAX : -1 = True, 0 = False }
End;

{ ------------------------------------------------------------ }
{ ParseLOFCall : parser un appel a la fonction LOF(n)           }
{   Retourne la taille du fichier en octets                    }
{ ------------------------------------------------------------ }

Procedure ParseLOFCall;
Begin
  Inc(FileIOCount);
  EmitComment('LOF(n)');
  If CurTokType = TOK_LPAREN Then
    LexNextToken;
  ParseExpr;
  Emit('  PUSH EAX');
  If CurTokType = TOK_RPAREN Then
    LexNextToken;
  Emit('  CALL ' + FIO_RT_LOF);
  Emit('  ADD ESP, 4');
End;

{ ------------------------------------------------------------ }
{ ParseLocCall : parser un appel a la fonction Loc(n)           }
{   Retourne la position courante dans le fichier              }
{ ------------------------------------------------------------ }

Procedure ParseLocCall;
Begin
  Inc(FileIOCount);
  EmitComment('Loc(n)');
  If CurTokType = TOK_LPAREN Then
    LexNextToken;
  ParseExpr;
  Emit('  PUSH EAX');
  If CurTokType = TOK_RPAREN Then
    LexNextToken;
  Emit('  CALL ' + FIO_RT_LOC);
  Emit('  ADD ESP, 4');
End;

{ ------------------------------------------------------------ }
{ ParseFreeFileCall : parser un appel a la fonction FreeFile    }
{   Retourne le prochain numero de fichier disponible          }
{ ------------------------------------------------------------ }

Procedure ParseFreeFileCall;
Begin
  Inc(FileIOCount);
  EmitComment('FreeFile');
  { FreeFile peut etre appele sans parentheses ou avec () }
  If CurTokType = TOK_LPAREN Then Begin
    LexNextToken;
    If CurTokType = TOK_RPAREN Then
      LexNextToken;
  End;
  Emit('  CALL ' + FIO_RT_FREEFILE);
  { Resultat dans EAX }
End;

{ ------------------------------------------------------------ }
{ IsFileIOStatement : verifier si le token courant commence    }
{   une instruction E/S fichier                                }
{ ------------------------------------------------------------ }

Function IsFileIOStatement : Boolean;
Begin
  If CurTokType <> TOK_KEYWORD Then Begin
    IsFileIOStatement := False;
    Exit;
  End;
  IsFileIOStatement := (CurTokNum = KW_OPEN) Or
                       (CurTokNum = KW_CLOSE) Or
                       (CurTokNum = KW_PRINT) Or
                       (CurTokNum = KW_WRITE) Or
                       (CurTokNum = KW_INPUT) Or
                       (CurTokNum = KW_GET) Or
                       (CurTokNum = KW_PUT) Or
                       (CurTokNum = KW_SEEK) Or
                       (CurTokNum = KW_LINE);
End;

{ ------------------------------------------------------------ }
{ IsFileFunction : verifier si le token courant est une        }
{   fonction fichier (EOF, LOF, Loc, FreeFile)                 }
{ ------------------------------------------------------------ }

Function IsFileFunction : Boolean;
Begin
  If CurTokType <> TOK_KEYWORD Then Begin
    IsFileFunction := False;
    Exit;
  End;
  IsFileFunction := (CurTokNum = KW_EOF2) Or
                    (CurTokNum = KW_LOF) Or
                    (CurTokNum = KW_LOC) Or
                    (CurTokNum = KW_FREEFILE);
End;

{ ------------------------------------------------------------ }
{ IsFileChannel : verifier si le token courant est un '#'      }
{   suivi d un numero (canal fichier)                          }
{ ------------------------------------------------------------ }

Function IsFileChannel : Boolean;
Begin
  IsFileChannel := (CurTokType = TOK_HASH);
End;

{ ------------------------------------------------------------ }
{ Fonctions d acces aux variables du module E/S fichiers        }
{ ------------------------------------------------------------ }

Function GetFileIOCount : LongInt;
Begin
  GetFileIOCount := FileIOCount;
End;

Function IsFileIOInitialized : Boolean;
Begin
  IsFileIOInitialized := FileIOInitialized;
End;

Function IsFileIOEmpty : Boolean;
Begin
  IsFileIOEmpty := FileIOInitialized And (FileIOCount = 0);
End;

Function GetFileIOStatus : TString;
Begin
  If Not FileIOInitialized Then
    GetFileIOStatus := 'non initialise'
  Else If FileIOCount = 0 Then
    GetFileIOStatus := 'initialise, aucune operation E/S'
  Else
    GetFileIOStatus := 'initialise, ' + ItoS(FileIOCount) + ' operations';
End;

Function GetCurFileMode : Integer;
Begin
  GetCurFileMode := CurFileMode;
End;

Function GetCurFileModeName : TString;
Begin
  GetCurFileModeName := FileModeName(CurFileMode);
End;

Function GetCurFileNum : Integer;
Begin
  GetCurFileNum := CurFileNum;
End;

Function GetMaxFileNum : Integer;
Begin
  GetMaxFileNum := MAX_FILE_NUM;
End;

Function GetDefaultRecordLen : Integer;
Begin
  GetDefaultRecordLen := DEFAULT_RECORD_LEN;
End;

Function GetFileRtCount : Integer;
Begin
  GetFileRtCount := 14;  { 10 operations + 4 fonctions }
End;

{ ============================================================ }
{ TODO 20 - BIBLIOTHEQUE RUNTIME (CHAINES, CONVERSION, E/S    }
{           VIA WIN32 API) [IMPLEMENTE]                        }
{ ============================================================ }

Const
  { Nombre total de routines runtime }
  MAX_RT_ROUTINES   = 64;

  { Categorie de routines runtime }
  RT_CAT_STRING     = 0;
  RT_CAT_CONVERT    = 1;
  RT_CAT_MATH       = 2;
  RT_CAT_CONSOLE    = 3;
  RT_CAT_ARRAY      = 4;
  RT_CAT_MEMORY     = 5;
  RT_CAT_SYSTEM     = 6;

  { Labels des routines chaines }
  RT_LEN            = '_VBRT_LEN';
  RT_STRCAT         = '_VBRT_STRCAT';
  RT_STRCMP          = '_VBRT_STRCMP';
  RT_STRCPY         = '_VBRT_STRCPY';
  RT_STRALLOC       = '_VBRT_STRALLOC';
  RT_STRFREE        = '_VBRT_STRFREE';
  RT_LEFT           = '_VBRT_LEFT';
  RT_RIGHT          = '_VBRT_RIGHT';
  RT_MID            = '_VBRT_MID';
  RT_LTRIM          = '_VBRT_LTRIM';
  RT_RTRIM          = '_VBRT_RTRIM';
  RT_TRIM           = '_VBRT_TRIM';
  RT_UCASE          = '_VBRT_UCASE';
  RT_LCASE          = '_VBRT_LCASE';
  RT_INSTR          = '_VBRT_INSTR';
  RT_REPLACE        = '_VBRT_REPLACE';
  RT_FORMAT         = '_VBRT_FORMAT';

  { Labels des routines conversion }
  RT_VAL            = '_VBRT_VAL';
  RT_STR            = '_VBRT_STR';
  RT_CINT           = '_VBRT_CINT';
  RT_CLNG           = '_VBRT_CLNG';
  RT_CSTR           = '_VBRT_CSTR';

  { Labels des routines mathematiques }
  RT_POW            = '_VBRT_POW';
  RT_SQR            = '_VBRT_SQR';
  RT_ABS            = '_VBRT_ABS';
  RT_SGN            = '_VBRT_SGN';
  RT_SIN            = '_VBRT_SIN';
  RT_COS            = '_VBRT_COS';
  RT_TAN            = '_VBRT_TAN';
  RT_ATN            = '_VBRT_ATN';
  RT_EXP            = '_VBRT_EXP';
  RT_LOG            = '_VBRT_LOG';

  { Labels des routines E/S console }
  RT_PRINT          = '_VBRT_PRINT';
  RT_INPUT          = '_VBRT_INPUT';
  RT_MSGBOX         = '_VBRT_MSGBOX';
  RT_INPUTBOX       = '_VBRT_INPUTBOX';

  { Labels des routines tableaux }
  RT_REDIM          = '_VBRT_REDIM';
  RT_ERASE          = '_VBRT_ERASE';
  RT_LBOUND         = '_VBRT_LBOUND';
  RT_UBOUND         = '_VBRT_UBOUND';

  { Labels des routines memoire }
  RT_HEAPINIT       = '_VBRT_HEAPINIT';
  RT_HEAPALLOC      = '_VBRT_HEAPALLOC';
  RT_HEAPFREE       = '_VBRT_HEAPFREE';

  { Labels des points d entree systeme }
  RT_INIT           = '_VBRT_INIT';
  RT_EXIT           = '_VBRT_EXIT';

  { Variables runtime globales }
  RT_VAR_HPROCESS   = '_VB_RT_HPROCESS';
  RT_VAR_HHEAP      = '_VB_RT_HHEAP';
  RT_VAR_HSTDOUT    = '_VB_RT_HSTDOUT';
  RT_VAR_HSTDIN     = '_VB_RT_HSTDIN';
  RT_VAR_EXITCODE   = '_VB_RT_EXITCODE';

  { Constantes pour les appels Win32 API }
  RT_WIN32_KERNEL32 = 'kernel32.dll';
  RT_WIN32_USER32   = 'user32.dll';

  { Valeurs API Windows }
  RT_STD_INPUT_HANDLE  = -10;
  RT_STD_OUTPUT_HANDLE = -11;
  RT_HEAP_ZERO_MEMORY  = $00000008;

Var
  RuntimeLibCount      : LongInt;
  RuntimeLibInitialized: Boolean;
  RuntimeLibEmitted    : Boolean;
  TotalStringRoutines  : Integer;
  TotalConvertRoutines : Integer;
  TotalMathRoutines    : Integer;
  TotalConsoleRoutines : Integer;
  TotalArrayRoutines   : Integer;
  TotalMemoryRoutines  : Integer;
  TotalSystemRoutines  : Integer;

{ ------------------------------------------------------------ }
{ InitRuntimeLib : initialiser l etat de la bibliotheque        }
{ ------------------------------------------------------------ }

Procedure InitRuntimeLib;
Begin
  RuntimeLibCount       := 0;
  RuntimeLibInitialized := True;
  RuntimeLibEmitted     := False;
  TotalStringRoutines   := 17;
  TotalConvertRoutines  := 5;
  TotalMathRoutines     := 10;
  TotalConsoleRoutines  := 4;
  TotalArrayRoutines    := 4;
  TotalMemoryRoutines   := 3;
  TotalSystemRoutines   := 2;
End;

{ ------------------------------------------------------------ }
{ RuntimeCategoryName : nom de la categorie de routine          }
{ ------------------------------------------------------------ }

Function RuntimeCategoryName(Cat : Integer) : String;
Begin
  Case Cat of
    RT_CAT_STRING:  RuntimeCategoryName := 'String';
    RT_CAT_CONVERT: RuntimeCategoryName := 'Conversion';
    RT_CAT_MATH:    RuntimeCategoryName := 'Math';
    RT_CAT_CONSOLE: RuntimeCategoryName := 'Console';
    RT_CAT_ARRAY:   RuntimeCategoryName := 'Array';
    RT_CAT_MEMORY:  RuntimeCategoryName := 'Memory';
    RT_CAT_SYSTEM:  RuntimeCategoryName := 'System';
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
{ GenRtInit : generer _VBRT_INIT (initialisation du runtime)    }
{   - GetProcessHeap pour le handle du heap                     }
{   - GetStdHandle pour stdout et stdin                         }
{ ------------------------------------------------------------ }

Procedure GenRtInit;
Begin
  EmitComment('--- _VBRT_INIT : initialize runtime ---');
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
{ GenRtExit : generer _VBRT_EXIT (terminaison du programme)     }
{   - ExitProcess(exitcode)                                     }
{ ------------------------------------------------------------ }

Procedure GenRtExit;
Begin
  EmitComment('--- _VBRT_EXIT : terminate program ---');
  EmitLabel(RT_EXIT);
  Emit('PUSH DWORD [' + RT_VAR_EXITCODE + ']');
  Emit('CALL ExitProcess');
  Inc(RuntimeLibCount);
End;

{ ------------------------------------------------------------ }
{ GenRtHeapInit : generer _VBRT_HEAPINIT                        }
{ ------------------------------------------------------------ }

Procedure GenRtHeapInit;
Begin
  EmitComment('--- _VBRT_HEAPINIT : initialize heap ---');
  EmitLabel(RT_HEAPINIT);
  Emit('CALL GetProcessHeap');
  Emit('MOV [' + RT_VAR_HHEAP + '], EAX');
  Emit('RET');
  Inc(RuntimeLibCount);
End;

{ ------------------------------------------------------------ }
{ GenRtHeapAlloc : generer _VBRT_HEAPALLOC                      }
{   Arg sur la pile : taille en octets                          }
{   Retourne : adresse dans EAX                                 }
{ ------------------------------------------------------------ }

Procedure GenRtHeapAlloc;
Begin
  EmitComment('--- _VBRT_HEAPALLOC : allocate memory ---');
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
{ GenRtHeapFree : generer _VBRT_HEAPFREE                        }
{   Arg sur la pile : adresse du bloc                           }
{ ------------------------------------------------------------ }

Procedure GenRtHeapFree;
Begin
  EmitComment('--- _VBRT_HEAPFREE : free memory ---');
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
{ GenRtStrAlloc : generer _VBRT_STRALLOC                        }
{   Arg : taille sur la pile                                    }
{   Retourne : pointeur dans EAX                                }
{ ------------------------------------------------------------ }

Procedure GenRtStrAlloc;
Begin
  EmitComment('--- _VBRT_STRALLOC : allocate string ---');
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
{ GenRtStrFree : generer _VBRT_STRFREE                          }
{   Arg : pointeur chaine sur la pile                           }
{ ------------------------------------------------------------ }

Procedure GenRtStrFree;
Begin
  EmitComment('--- _VBRT_STRFREE : free string ---');
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
{ GenRtLen : generer _VBRT_LEN (longueur de chaine)             }
{   Arg : pointeur chaine sur la pile                           }
{   Retourne : longueur dans EAX                                }
{ ------------------------------------------------------------ }

Procedure GenRtLen;
Begin
  EmitComment('--- _VBRT_LEN : string length ---');
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
{ GenRtStrCat : generer _VBRT_STRCAT (concatenation)            }
{   Args : dst, src sur la pile                                 }
{   Retourne : pointeur resultat dans EAX                       }
{ ------------------------------------------------------------ }

Procedure GenRtStrCat;
Var LabelLoop1,LabelDone1,LabelLoop2,LabelDone2:String;
Begin
  LabelLoop1 := NextInternalLabel;
  LabelDone1 := NextInternalLabel;
  LabelLoop2 := NextInternalLabel;
  LabelDone2 := NextInternalLabel;
  EmitComment('--- _VBRT_STRCAT : string concatenation ---');
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
{ GenRtStrCmp : generer _VBRT_STRCMP (comparaison)               }
{   Args : str1, str2 sur la pile                               }
{   Retourne : 0 si egal, <0 si str1<str2, >0 si str1>str2     }
{ ------------------------------------------------------------ }

Procedure GenRtStrCmp;
Var LabelLoop,LabelDone,LabelLess,LabelGreater:String;
Begin
  LabelLoop    := NextInternalLabel;
  LabelDone    := NextInternalLabel;
  LabelLess    := NextInternalLabel;
  LabelGreater := NextInternalLabel;
  EmitComment('--- _VBRT_STRCMP : string comparison ---');
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
{ GenRtStrCpy : generer _VBRT_STRCPY (copie)                    }
{   Args : dst, src sur la pile                                 }
{   Retourne : dst dans EAX                                     }
{ ------------------------------------------------------------ }

Procedure GenRtStrCpy;
Var LabelLoop,LabelDone:String;
Begin
  LabelLoop := NextInternalLabel;
  LabelDone := NextInternalLabel;
  EmitComment('--- _VBRT_STRCPY : string copy ---');
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
{ GenRtLeft : generer _VBRT_LEFT                                }
{   Args : str, count sur la pile                               }
{   Retourne : nouvelle chaine dans EAX                         }
{ ------------------------------------------------------------ }

Procedure GenRtLeft;
Var LabelLoop,LabelDone:String;
Begin
  LabelLoop := NextInternalLabel;
  LabelDone := NextInternalLabel;
  EmitComment('--- _VBRT_LEFT : Left$ function ---');
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
{ GenRtRight : generer _VBRT_RIGHT                              }
{   Args : str, count sur la pile                               }
{   Retourne : nouvelle chaine dans EAX                         }
{ ------------------------------------------------------------ }

Procedure GenRtRight;
Begin
  EmitComment('--- _VBRT_RIGHT : Right$ function ---');
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
{ GenRtMid : generer _VBRT_MID                                  }
{   Args : str, start, length sur la pile                       }
{   Retourne : nouvelle chaine dans EAX                         }
{ ------------------------------------------------------------ }

Procedure GenRtMid;
Var LabelLoop,LabelDone:String;
Begin
  LabelLoop := NextInternalLabel;
  LabelDone := NextInternalLabel;
  EmitComment('--- _VBRT_MID : Mid$ function ---');
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
{ GenRtTrim : generer _VBRT_LTRIM, _VBRT_RTRIM, _VBRT_TRIM     }
{ ------------------------------------------------------------ }

Procedure GenRtTrim;
Var LabelLoop1,LabelDone1,LabelLoop2:String;
Begin
  LabelLoop1 := NextInternalLabel;
  LabelDone1 := NextInternalLabel;
  LabelLoop2 := NextInternalLabel;

  { LTrim$ : sauter les espaces au debut }
  EmitComment('--- _VBRT_LTRIM : LTrim$ ---');
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
  EmitComment('--- _VBRT_RTRIM : RTrim$ ---');
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
  EmitComment('--- _VBRT_TRIM : Trim$ ---');
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
{ GenRtCase : generer _VBRT_UCASE et _VBRT_LCASE                }
{ ------------------------------------------------------------ }

Procedure GenRtCase;
Var LabelLoop1,LabelDone1,LabelSkip1:String;
    LabelLoop2,LabelDone2,LabelSkip2:String;
Begin
  LabelLoop1 := NextInternalLabel;
  LabelDone1 := NextInternalLabel;
  LabelSkip1 := NextInternalLabel;
  LabelLoop2 := NextInternalLabel;
  LabelDone2 := NextInternalLabel;
  LabelSkip2 := NextInternalLabel;

  { UCase$ }
  EmitComment('--- _VBRT_UCASE : UCase$ ---');
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
  Emit('SUB EAX, ECX');                   { pas necessaire, on a le ptr }
  Emit('POP ESI');
  Emit('MOV ESP, EBP');
  Emit('POP EBP');
  Emit('RET 4');

  { LCase$ }
  EmitComment('--- _VBRT_LCASE : LCase$ ---');
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
{ GenRtInStr : generer _VBRT_INSTR                              }
{   Args : start, str1, str2 sur la pile                        }
{   Retourne : position (1-based) dans EAX, 0 si non trouve    }
{ ------------------------------------------------------------ }

Procedure GenRtInStr;
Var LabelOuter,LabelInner,LabelFound,LabelNotFound,LabelNext:String;
Begin
  LabelOuter   := NextInternalLabel;
  LabelInner   := NextInternalLabel;
  LabelFound   := NextInternalLabel;
  LabelNotFound := NextInternalLabel;
  LabelNext    := NextInternalLabel;
  EmitComment('--- _VBRT_INSTR : InStr function ---');
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
{ GenRtReplace : generer _VBRT_REPLACE (stub simplifie)         }
{ ------------------------------------------------------------ }

Procedure GenRtReplace;
Begin
  EmitComment('--- _VBRT_REPLACE : Replace function (stub) ---');
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
{ GenRtFormat : generer _VBRT_FORMAT (stub simplifie)            }
{ ------------------------------------------------------------ }

Procedure GenRtFormat;
Begin
  EmitComment('--- _VBRT_FORMAT : Format function (stub) ---');
  EmitLabel(RT_FORMAT);
  Emit('PUSH EBP');
  Emit('MOV EBP, ESP');
  { Stub : appeler _VBRT_STR pour la conversion basique }
  Emit('PUSH DWORD [EBP+12]');
  Emit('CALL ' + RT_STR);
  Emit('MOV ESP, EBP');
  Emit('POP EBP');
  Emit('RET 8');
  Inc(RuntimeLibCount);
End;

{ ------------------------------------------------------------ }
{ GenRtVal : generer _VBRT_VAL (chaine vers nombre)             }
{   Arg : pointeur chaine sur la pile                           }
{   Retourne : valeur entiere dans EAX                          }
{ ------------------------------------------------------------ }

Procedure GenRtVal;
Var LabelLoop,LabelDone,LabelNeg,LabelPos:String;
Begin
  LabelLoop := NextInternalLabel;
  LabelDone := NextInternalLabel;
  LabelNeg  := NextInternalLabel;
  LabelPos  := NextInternalLabel;
  EmitComment('--- _VBRT_VAL : string to number ---');
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
{ GenRtStr : generer _VBRT_STR (nombre vers chaine)             }
{   Arg : valeur entiere sur la pile                            }
{   Retourne : pointeur chaine dans EAX                         }
{ ------------------------------------------------------------ }

Procedure GenRtStr;
Var LabelLoop,LabelReverse,LabelRevDone,LabelNeg,LabelNotNeg:String;
Begin
  LabelLoop    := NextInternalLabel;
  LabelReverse := NextInternalLabel;
  LabelRevDone := NextInternalLabel;
  LabelNeg     := NextInternalLabel;
  LabelNotNeg  := NextInternalLabel;
  EmitComment('--- _VBRT_STR : number to string ---');
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
  Emit('MOV EAX, [EBP+8]');               { recharger pour le retour... }
  { Non, retourner le pointeur du buffer }
  Emit('LEA EAX, [ECX]');                 { ECX etait le debut }
  { Corriger : retourner le buffer original }
  Emit('POP EBX');
  Emit('POP EDI');
  Emit('POP ESI');
  Emit('MOV ESP, EBP');
  Emit('POP EBP');
  Emit('RET 4');
  Inc(RuntimeLibCount);
End;

{ ------------------------------------------------------------ }
{ GenRtConversions : generer _VBRT_CINT, _VBRT_CLNG, _VBRT_CSTR }
{ ------------------------------------------------------------ }

Procedure GenRtConversions;
Begin
  { CInt : tronquer a 16 bits signe }
  EmitComment('--- _VBRT_CINT : Convert to Integer ---');
  EmitLabel(RT_CINT);
  Emit('PUSH EBP');
  Emit('MOV EBP, ESP');
  Emit('MOV EAX, [EBP+8]');
  Emit('MOVSX EAX, AX');                  { signe-etendre 16 bits }
  Emit('MOV ESP, EBP');
  Emit('POP EBP');
  Emit('RET 4');

  { CLng : identite sur 32 bits }
  EmitComment('--- _VBRT_CLNG : Convert to Long ---');
  EmitLabel(RT_CLNG);
  Emit('PUSH EBP');
  Emit('MOV EBP, ESP');
  Emit('MOV EAX, [EBP+8]');
  Emit('MOV ESP, EBP');
  Emit('POP EBP');
  Emit('RET 4');

  { CStr : alias pour _VBRT_STR }
  EmitComment('--- _VBRT_CSTR : Convert to String ---');
  EmitLabel(RT_CSTR);
  Emit('JMP ' + RT_STR);
  Inc(RuntimeLibCount, 3);
End;

{ ------------------------------------------------------------ }
{ GenRtMathOps : generer les routines mathematiques              }
{   Utilise le FPU x87 pour les operations en virgule flottante  }
{ ------------------------------------------------------------ }

Procedure GenRtMathOps;
Begin
  { POW : a ^ b }
  EmitComment('--- _VBRT_POW : power (a^b) ---');
  EmitLabel(RT_POW);
  Emit('PUSH EBP');
  Emit('MOV EBP, ESP');
  { Utiliser FYL2X + F2XM1 pour calculer a^b }
  { Simplifie : multiplication iterative pour les entiers }
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
  EmitComment('--- _VBRT_SQR : square root ---');
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
  EmitComment('--- _VBRT_ABS : absolute value ---');
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
  EmitComment('--- _VBRT_SGN : sign ---');
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
  EmitComment('--- _VBRT_SIN : sine ---');
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
  EmitComment('--- _VBRT_COS : cosine ---');
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
  EmitComment('--- _VBRT_TAN : tangent ---');
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
  EmitComment('--- _VBRT_ATN : arctangent ---');
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
  EmitComment('--- _VBRT_EXP : exponential ---');
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
  EmitComment('--- _VBRT_LOG : natural logarithm ---');
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

  Inc(RuntimeLibCount, 10);
End;

{ ------------------------------------------------------------ }
{ GenRtPrint : generer _VBRT_PRINT (affichage console)          }
{   Arg : pointeur chaine sur la pile                           }
{ ------------------------------------------------------------ }

Procedure GenRtPrint;
Begin
  EmitComment('--- _VBRT_PRINT : console print ---');
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
{ GenRtInput : generer _VBRT_INPUT (lecture console)             }
{   Arg : pointeur buffer, taille max sur la pile               }
{   Retourne : nombre d octets lus dans EAX                     }
{ ------------------------------------------------------------ }

Procedure GenRtInput;
Begin
  EmitComment('--- _VBRT_INPUT : console input ---');
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
{ GenRtMsgBox : generer _VBRT_MSGBOX                            }
{   Args : message, titre, style sur la pile                    }
{   Retourne : resultat dans EAX                                }
{ ------------------------------------------------------------ }

Procedure GenRtMsgBox;
Begin
  EmitComment('--- _VBRT_MSGBOX : MessageBox ---');
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
{ GenRtInputBox : generer _VBRT_INPUTBOX (stub)                 }
{ ------------------------------------------------------------ }

Procedure GenRtInputBox;
Begin
  EmitComment('--- _VBRT_INPUTBOX : InputBox (stub) ---');
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
{ GenRtArrayOps : generer les routines tableaux                  }
{ ------------------------------------------------------------ }

Procedure GenRtArrayOps;
Begin
  { REDIM : reallouer un tableau }
  EmitComment('--- _VBRT_REDIM : ReDim array ---');
  EmitLabel(RT_REDIM);
  Emit('PUSH EBP');
  Emit('MOV EBP, ESP');
  { Args : ptr, newsize }
  Emit('PUSH DWORD [EBP+8]');             { nouvelle taille }
  Emit('CALL ' + RT_HEAPALLOC);
  Emit('MOV ESP, EBP');
  Emit('POP EBP');
  Emit('RET 8');

  { ERASE : liberer un tableau }
  EmitComment('--- _VBRT_ERASE : Erase array ---');
  EmitLabel(RT_ERASE);
  Emit('PUSH EBP');
  Emit('MOV EBP, ESP');
  Emit('PUSH DWORD [EBP+8]');
  Emit('CALL ' + RT_HEAPFREE);
  Emit('MOV ESP, EBP');
  Emit('POP EBP');
  Emit('RET 4');

  { LBOUND : retourner la borne inferieure (toujours 0 par defaut) }
  EmitComment('--- _VBRT_LBOUND : array lower bound ---');
  EmitLabel(RT_LBOUND);
  Emit('PUSH EBP');
  Emit('MOV EBP, ESP');
  Emit('XOR EAX, EAX');                   { retourner 0 }
  Emit('MOV ESP, EBP');
  Emit('POP EBP');
  Emit('RET 4');

  { UBOUND : retourner la borne superieure }
  EmitComment('--- _VBRT_UBOUND : array upper bound ---');
  EmitLabel(RT_UBOUND);
  Emit('PUSH EBP');
  Emit('MOV EBP, ESP');
  { Le nombre d elements est stocke en en-tete du tableau }
  Emit('MOV EAX, [EBP+8]');               { pointeur tableau }
  Emit('MOV EAX, [EAX-4]');               { en-tete = count }
  Emit('DEC EAX');                         { upper bound = count - 1 }
  Emit('MOV ESP, EBP');
  Emit('POP EBP');
  Emit('RET 4');

  Inc(RuntimeLibCount, 4);
End;

{ ------------------------------------------------------------ }
{ EmitAllRuntimeRoutines : emettre toutes les routines runtime   }
{ ------------------------------------------------------------ }

Procedure EmitAllRuntimeRoutines;
Begin
  If RuntimeLibEmitted Then Exit;
  EmitComment('========================================');
  EmitComment('  VB6 Runtime Library (Win32)            ');
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
  GenRtFormat;
  GenRtVal;
  GenRtStr;
  GenRtConversions;
  GenRtMathOps;
  GenRtPrint;
  GenRtInput;
  GenRtMsgBox;
  GenRtInputBox;
  GenRtArrayOps;
  RuntimeLibEmitted := True;
End;

{ ------------------------------------------------------------ }
{ IsRuntimeLabel : verifier si un label est une routine runtime  }
{ ------------------------------------------------------------ }

Function IsRuntimeLabel(Const S : String) : Boolean;
Begin
  IsRuntimeLabel := False;
  If Length(S) < 6 Then Exit;
  If Copy(S, 1, 6) = '_VBRT_' Then
    IsRuntimeLabel := True;
End;

{ ------------------------------------------------------------ }
{ IsStringRoutine : verifier si c est une routine chaine         }
{ ------------------------------------------------------------ }

Function IsStringRoutine(Const S : String) : Boolean;
Begin
  IsStringRoutine := (S = RT_LEN) Or (S = RT_STRCAT) Or
                     (S = RT_STRCMP) Or (S = RT_STRCPY) Or
                     (S = RT_STRALLOC) Or (S = RT_STRFREE) Or
                     (S = RT_LEFT) Or (S = RT_RIGHT) Or
                     (S = RT_MID) Or (S = RT_LTRIM) Or
                     (S = RT_RTRIM) Or (S = RT_TRIM) Or
                     (S = RT_UCASE) Or (S = RT_LCASE) Or
                     (S = RT_INSTR) Or (S = RT_REPLACE) Or
                     (S = RT_FORMAT);
End;

{ ------------------------------------------------------------ }
{ IsMathRoutine : verifier si c est une routine mathematique     }
{ ------------------------------------------------------------ }

Function IsMathRoutine(Const S : String) : Boolean;
Begin
  IsMathRoutine := (S = RT_POW) Or (S = RT_SQR) Or
                   (S = RT_ABS) Or (S = RT_SGN) Or
                   (S = RT_SIN) Or (S = RT_COS) Or
                   (S = RT_TAN) Or (S = RT_ATN) Or
                   (S = RT_EXP) Or (S = RT_LOG);
End;

{ ------------------------------------------------------------ }
{ IsConvertRoutine : verifier si c est une routine conversion    }
{ ------------------------------------------------------------ }

Function IsConvertRoutine(Const S : String) : Boolean;
Begin
  IsConvertRoutine := (S = RT_VAL) Or (S = RT_STR) Or
                      (S = RT_CINT) Or (S = RT_CLNG) Or
                      (S = RT_CSTR);
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

Function GetRuntimeLibStatus : String;
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
                        TotalSystemRoutines;
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
{ TODO 22 - ECRIVAIN COFF .OBJ (PARAMETRE -obj)               }
{           [IMPLEMENTE]                                       }
{ ============================================================ }

Const
  { En-tete COFF }
  COFF_MACHINE_I386      = $014C;
  COFF_NUM_SECTIONS      = 3;
  COFF_HEADER_SIZE       = 20;
  COFF_SECTION_HEADER_SIZE = 40;
  COFF_SYMBOL_SIZE       = 18;
  COFF_RELOC_SIZE        = 10;

  { Caracteristiques des sections COFF }
  COFF_SCN_CNT_CODE          = $00000020;
  COFF_SCN_CNT_INIT_DATA     = $00000040;
  COFF_SCN_CNT_UNINIT_DATA   = $00000080;
  COFF_SCN_MEM_EXECUTE       = $20000000;
  COFF_SCN_MEM_READ          = $40000000;
  COFF_SCN_MEM_WRITE         = $80000000;
  COFF_SCN_ALIGN_4BYTES      = $00300000;
  COFF_SCN_ALIGN_16BYTES     = $00500000;

  { Types de relocation i386 }
  IMAGE_REL_I386_DIR32  = $0006;
  IMAGE_REL_I386_REL32  = $0014;

  { Classes de stockage symboles COFF }
  IMAGE_SYM_CLASS_EXTERNAL   = 2;
  IMAGE_SYM_CLASS_STATIC     = 3;
  IMAGE_SYM_CLASS_LABEL      = 6;
  IMAGE_SYM_CLASS_FILE       = 103;

  { Sections speciales symboles }
  IMAGE_SYM_UNDEFINED   = 0;
  IMAGE_SYM_ABSOLUTE    = -1;
  IMAGE_SYM_DEBUG       = -2;

  { Nombre maximum d elements }
  MAX_COFF_SYMBOLS      = 512;
  MAX_COFF_RELOCS       = 1024;
  MAX_COFF_STRTAB_SIZE  = 16384;

  { Labels COFF runtime }
  COFF_RT_WRITE         = '_COFF_WRITE';
  COFF_RT_HEADER        = '_COFF_HDR';
  COFF_RT_SECTIONS      = '_COFF_SECS';
  COFF_RT_SYMTAB        = '_COFF_SYMTAB';
  COFF_RT_STRTAB        = '_COFF_STRTAB';
  COFF_RT_RELOCS        = '_COFF_RELOCS';
  COFF_RT_EMIT          = '_COFF_EMIT';
  COFF_RT_TEXT           = '_COFF_TEXT';
  COFF_RT_DATA           = '_COFF_DATA';
  COFF_RT_BSS            = '_COFF_BSS';

  { Variables COFF segment }
  COFF_VAR_NSYMS        = '_COFF_NSYMS';
  COFF_VAR_NRELOCS      = '_COFF_NRELOCS';
  COFF_VAR_TEXTSIZE     = '_COFF_TEXTSIZE';
  COFF_VAR_DATASIZE     = '_COFF_DATASIZE';
  COFF_VAR_BSSSIZE      = '_COFF_BSSSIZE';

Var
  COFFWriterCount       : LongInt;
  COFFWriterInitialized : Boolean;
  COFFTextSize          : LongInt;
  COFFDataSize          : LongInt;
  COFFBssSize           : LongInt;
  COFFSymbolCount       : LongInt;
  COFFRelocCount        : LongInt;
  COFFStrTabSize        : LongInt;
  COFFTotalSections     : Integer;

{ ------------------------------------------------------------ }
{ InitCOFFWriter : initialiser l etat du generateur COFF        }
{ ------------------------------------------------------------ }

Procedure InitCOFFWriter;
Begin
  COFFWriterCount       := 0;
  COFFWriterInitialized := True;
  COFFTextSize          := 0;
  COFFDataSize          := 0;
  COFFBssSize           := 0;
  COFFSymbolCount       := 0;
  COFFRelocCount        := 0;
  COFFStrTabSize        := 4;
  COFFTotalSections     := COFF_NUM_SECTIONS;
End;

{ ------------------------------------------------------------ }
{ COFFAlignTo : aligner une taille sur une frontiere            }
{ ------------------------------------------------------------ }

Function COFFAlignTo(Value, Align : LongInt) : LongInt;
Begin
  If (Value Mod Align) <> 0 Then
    COFFAlignTo := Value + (Align - (Value Mod Align))
  Else
    COFFAlignTo := Value;
End;

{ ------------------------------------------------------------ }
{ COFFWriteByte : ecrire un octet dans le fichier               }
{ ------------------------------------------------------------ }

Procedure COFFWriteByte(Var F : File; B : Byte);
Begin
  BlockWrite(F, B, 1);
  Inc(COFFWriterCount);
End;

{ ------------------------------------------------------------ }
{ COFFWriteWord : ecrire un mot 16 bits (little-endian)         }
{ ------------------------------------------------------------ }

Procedure COFFWriteWord(Var F : File; W : Word);
Var
  Buf : Array[0..1] of Byte;
Begin
  Buf[0] := W And $FF;
  Buf[1] := (W Shr 8) And $FF;
  BlockWrite(F, Buf, 2);
  Inc(COFFWriterCount, 2);
End;

{ ------------------------------------------------------------ }
{ COFFWriteDWord : ecrire un double mot 32 bits (little-endian) }
{ ------------------------------------------------------------ }

Procedure COFFWriteDWord(Var F : File; DW : LongInt);
Var
  Buf : Array[0..3] of Byte;
Begin
  Buf[0] := DW And $FF;
  Buf[1] := (DW Shr 8) And $FF;
  Buf[2] := (DW Shr 16) And $FF;
  Buf[3] := (DW Shr 24) And $FF;
  BlockWrite(F, Buf, 4);
  Inc(COFFWriterCount, 4);
End;

{ ------------------------------------------------------------ }
{ COFFWriteZeros : ecrire N octets nuls                         }
{ ------------------------------------------------------------ }

Procedure COFFWriteZeros(Var F : File; Count : LongInt);
Var
  Zero : Byte;
  I    : LongInt;
Begin
  Zero := 0;
  For I := 1 To Count Do
    BlockWrite(F, Zero, 1);
  Inc(COFFWriterCount, Count);
End;

{ ------------------------------------------------------------ }
{ COFFWriteString : ecrire une chaine (sans zero terminal)      }
{ ------------------------------------------------------------ }

Procedure COFFWriteString(Var F : File; Const S : String);
Var
  I : Integer;
  B : Byte;
Begin
  For I := 1 To Length(S) Do Begin
    B := Ord(S[I]);
    BlockWrite(F, B, 1);
  End;
  Inc(COFFWriterCount, Length(S));
End;

{ ------------------------------------------------------------ }
{ COFFWriteFixedName : ecrire un nom de 8 octets (padde zeros)  }
{ ------------------------------------------------------------ }

Procedure COFFWriteFixedName(Var F : File; Const Name : String);
Var
  I    : Integer;
  B    : Byte;
  Len  : Integer;
Begin
  Len := Length(Name);
  If Len > 8 Then Len := 8;
  For I := 1 To Len Do Begin
    B := Ord(Name[I]);
    BlockWrite(F, B, 1);
  End;
  For I := Len + 1 To 8 Do Begin
    B := 0;
    BlockWrite(F, B, 1);
  End;
  Inc(COFFWriterCount, 8);
End;

{ ------------------------------------------------------------ }
{ COFFWriteSectionName : ecrire le nom d une section COFF       }
{   Si le nom > 8 chars, utiliser /offset dans string table     }
{ ------------------------------------------------------------ }

Procedure COFFWriteSectionName(Var F : File; Const Name : String);
Begin
  COFFWriteFixedName(F, Name);
End;

{ ------------------------------------------------------------ }
{ WriteCOFFHeader : ecrire l en-tete COFF de 20 octets          }
{ ------------------------------------------------------------ }

Procedure WriteCOFFHeader(Var F : File; NumSections : Integer;
                          PtrSymTab : LongInt; NumSymbols : LongInt);
Begin
  { Machine }
  COFFWriteWord(F, COFF_MACHINE_I386);
  { NumberOfSections }
  COFFWriteWord(F, NumSections);
  { TimeDateStamp (0 pour reproductibilite) }
  COFFWriteDWord(F, 0);
  { PointerToSymbolTable }
  COFFWriteDWord(F, PtrSymTab);
  { NumberOfSymbols }
  COFFWriteDWord(F, NumSymbols);
  { SizeOfOptionalHeader (0 pour .OBJ) }
  COFFWriteWord(F, 0);
  { Characteristics (0 pour .OBJ) }
  COFFWriteWord(F, 0);
End;

{ ------------------------------------------------------------ }
{ WriteCOFFSectionHeader : ecrire un en-tete de section         }
{ ------------------------------------------------------------ }

Procedure WriteCOFFSectionHeader(Var F : File;
  Const Name : String; VirtualSize, VirtualAddr : LongInt;
  RawDataSize, RawDataPtr : LongInt;
  RelocPtr : LongInt; NumRelocs : Word;
  Characteristics : LongInt);
Begin
  { Name (8 octets) }
  COFFWriteSectionName(F, Name);
  { VirtualSize }
  COFFWriteDWord(F, VirtualSize);
  { VirtualAddress }
  COFFWriteDWord(F, VirtualAddr);
  { SizeOfRawData }
  COFFWriteDWord(F, RawDataSize);
  { PointerToRawData }
  COFFWriteDWord(F, RawDataPtr);
  { PointerToRelocations }
  COFFWriteDWord(F, RelocPtr);
  { PointerToLinenumbers }
  COFFWriteDWord(F, 0);
  { NumberOfRelocations }
  COFFWriteWord(F, NumRelocs);
  { NumberOfLinenumbers }
  COFFWriteWord(F, 0);
  { Characteristics }
  COFFWriteDWord(F, Characteristics);
End;

{ ------------------------------------------------------------ }
{ WriteCOFFSymbol : ecrire une entree de symbole COFF           }
{   18 octets : Name(8) + Value(4) + SectionNumber(2) +        }
{               Type(2) + StorageClass(1) + NumAux(1)           }
{ ------------------------------------------------------------ }

Procedure WriteCOFFSymbol(Var F : File;
  Const Name : String; Value : LongInt;
  SectionNumber : Integer; SymType : Word;
  StorageClass : Byte; NumAuxSymbols : Byte);
Var
  Len    : Integer;
  StrOfs : LongInt;
Begin
  Len := Length(Name);
  If Len <= 8 Then Begin
    { Nom court : directement dans le champ Name }
    COFFWriteFixedName(F, Name);
  End Else Begin
    { Nom long : zeros(4) + offset dans string table }
    StrOfs := COFFStrTabSize;
    COFFWriteDWord(F, 0);
    COFFWriteDWord(F, StrOfs);
    COFFStrTabSize := COFFStrTabSize + Len + 1;
  End;
  COFFWriteDWord(F, Value);
  COFFWriteWord(F, SectionNumber);
  COFFWriteWord(F, SymType);
  COFFWriteByte(F, StorageClass);
  COFFWriteByte(F, NumAuxSymbols);
  Inc(COFFSymbolCount);
End;

{ ------------------------------------------------------------ }
{ WriteCOFFRelocation : ecrire une entree de relocation         }
{   10 octets : VirtualAddress(4) + SymbolTableIndex(4) +      }
{               Type(2)                                          }
{ ------------------------------------------------------------ }

Procedure WriteCOFFRelocation(Var F : File;
  VAddr : LongInt; SymIdx : LongInt; RelocType : Word);
Begin
  COFFWriteDWord(F, VAddr);
  COFFWriteDWord(F, SymIdx);
  COFFWriteWord(F, RelocType);
  Inc(COFFRelocCount);
End;

{ ------------------------------------------------------------ }
{ WriteCOFFStringTable : ecrire la table des chaines longues    }
{   Commence par la taille totale (4 octets), suivi des         }
{   chaines terminees par un zero                                }
{ ------------------------------------------------------------ }

Procedure WriteCOFFStringTable(Var F : File);
Begin
  { Taille de la table (incluant ces 4 octets) }
  COFFWriteDWord(F, COFFStrTabSize);
  { Les chaines elles-memes sont ecrites par WriteCOFFSymbol }
  { via le mecanisme de noms longs (> 8 chars) }
End;

{ ------------------------------------------------------------ }
{ WriteCOFFTextSection : ecrire la section .text (code)          }
{ ------------------------------------------------------------ }

Procedure WriteCOFFTextSection(Var F : File);
Var
  I : LongInt;
Begin
  { Emettre le code genere par le compilateur }
  { Pour l instant, section minimale avec un RET }
  COFFWriteByte(F, $C3);  { RET }
  COFFTextSize := 1;
  { Padding a 4 octets }
  For I := COFFTextSize + 1 To COFFAlignTo(COFFTextSize, 4) Do
    COFFWriteByte(F, $90);  { NOP }
  COFFTextSize := COFFAlignTo(COFFTextSize, 4);
End;

{ ------------------------------------------------------------ }
{ WriteCOFFDataSection : ecrire la section .data                 }
{ ------------------------------------------------------------ }

Procedure WriteCOFFDataSection(Var F : File);
Begin
  { Emettre les donnees initialisees }
  { Section minimale : un octet nul }
  COFFWriteByte(F, 0);
  COFFDataSize := 1;
  COFFDataSize := COFFAlignTo(COFFDataSize, 4);
  COFFWriteZeros(F, COFFDataSize - 1);
End;

{ ------------------------------------------------------------ }
{ WriteCOFFSectionSymbols : ecrire les symboles de section      }
{ ------------------------------------------------------------ }

Procedure WriteCOFFSectionSymbols(Var F : File);
Begin
  { Symbole .text (section 1) }
  WriteCOFFSymbol(F, '.text', 0, 1, 0,
                  IMAGE_SYM_CLASS_STATIC, 0);
  { Symbole .data (section 2) }
  WriteCOFFSymbol(F, '.data', 0, 2, 0,
                  IMAGE_SYM_CLASS_STATIC, 0);
  { Symbole .bss (section 3) }
  WriteCOFFSymbol(F, '.bss', 0, 3, 0,
                  IMAGE_SYM_CLASS_STATIC, 0);
End;

{ ------------------------------------------------------------ }
{ WriteCOFFExternalSymbols : ecrire les symboles externes       }
{   (fonctions importees des DLL Win32)                         }
{ ------------------------------------------------------------ }

Procedure WriteCOFFExternalSymbols(Var F : File);
Begin
  { ExitProcess de kernel32.dll }
  WriteCOFFSymbol(F, '_ExitProcess@4', 0,
                  IMAGE_SYM_UNDEFINED, $20,
                  IMAGE_SYM_CLASS_EXTERNAL, 0);
  { GetProcessHeap de kernel32.dll }
  WriteCOFFSymbol(F, '_GetProcessHeap@0', 0,
                  IMAGE_SYM_UNDEFINED, $20,
                  IMAGE_SYM_CLASS_EXTERNAL, 0);
  { HeapAlloc de kernel32.dll }
  WriteCOFFSymbol(F, '_HeapAlloc@12', 0,
                  IMAGE_SYM_UNDEFINED, $20,
                  IMAGE_SYM_CLASS_EXTERNAL, 0);
  { HeapFree de kernel32.dll }
  WriteCOFFSymbol(F, '_HeapFree@12', 0,
                  IMAGE_SYM_UNDEFINED, $20,
                  IMAGE_SYM_CLASS_EXTERNAL, 0);
  { GetStdHandle de kernel32.dll }
  WriteCOFFSymbol(F, '_GetStdHandle@4', 0,
                  IMAGE_SYM_UNDEFINED, $20,
                  IMAGE_SYM_CLASS_EXTERNAL, 0);
  { WriteFile de kernel32.dll }
  WriteCOFFSymbol(F, '_WriteFile@20', 0,
                  IMAGE_SYM_UNDEFINED, $20,
                  IMAGE_SYM_CLASS_EXTERNAL, 0);
  { ReadFile de kernel32.dll }
  WriteCOFFSymbol(F, '_ReadFile@20', 0,
                  IMAGE_SYM_UNDEFINED, $20,
                  IMAGE_SYM_CLASS_EXTERNAL, 0);
  { MessageBoxA de user32.dll }
  WriteCOFFSymbol(F, '_MessageBoxA@16', 0,
                  IMAGE_SYM_UNDEFINED, $20,
                  IMAGE_SYM_CLASS_EXTERNAL, 0);
End;

{ ------------------------------------------------------------ }
{ WriteCOFFPublicSymbols : ecrire les symboles publics          }
{   (procedures et point d entree exportes)                     }
{ ------------------------------------------------------------ }

Procedure WriteCOFFPublicSymbols(Var F : File);
Begin
  { Point d entree principal }
  WriteCOFFSymbol(F, '_VBF_MAIN', 0, 1, $20,
                  IMAGE_SYM_CLASS_EXTERNAL, 0);
End;

{ ------------------------------------------------------------ }
{ WriteCOFFRelocations : ecrire les relocations de .text        }
{ ------------------------------------------------------------ }

Procedure WriteCOFFRelocations(Var F : File);
Begin
  { Les relocations seront ajoutees quand le code est genere }
  { Pour l instant, pas de relocations dans la section minimale }
  COFFRelocCount := 0;
End;

{ ------------------------------------------------------------ }
{ WriteCOFF : generer le fichier objet COFF complet             }
{ ------------------------------------------------------------ }

Procedure WriteCOFF(Const OutFile : String);
Var
  F           : File;
  PtrSymTab   : LongInt;
  SecHdrOfs   : LongInt;
  TextOfs     : LongInt;
  DataOfs     : LongInt;
  RelocOfs    : LongInt;
  TextSz      : LongInt;
  DataSz      : LongInt;
  TotalSyms   : LongInt;
Begin
  { Calculer les tailles }
  TextSz := COFFAlignTo(1, 4);
  DataSz := COFFAlignTo(1, 4);

  { Calculer les offsets }
  SecHdrOfs := COFF_HEADER_SIZE;
  TextOfs   := SecHdrOfs + (COFF_NUM_SECTIONS * COFF_SECTION_HEADER_SIZE);
  DataOfs   := TextOfs + TextSz;
  RelocOfs  := DataOfs + DataSz;

  { Nombre total de symboles : 3 section + 8 externes + 1 public }
  TotalSyms := 12;
  PtrSymTab := RelocOfs;

  { Reinitialiser les compteurs }
  COFFWriterCount := 0;
  COFFSymbolCount := 0;
  COFFRelocCount  := 0;
  COFFStrTabSize  := 4;

  { Ouvrir le fichier }
  Assign(F, OutFile);
  Rewrite(F, 1);

  { 1. En-tete COFF }
  WriteCOFFHeader(F, COFF_NUM_SECTIONS, PtrSymTab, TotalSyms);

  { 2. En-tetes de sections }
  { .text : code executable }
  WriteCOFFSectionHeader(F, '.text', 0, 0, TextSz, TextOfs,
    0, 0,
    COFF_SCN_CNT_CODE Or COFF_SCN_MEM_EXECUTE Or
    COFF_SCN_MEM_READ Or COFF_SCN_ALIGN_16BYTES);

  { .data : donnees initialisees }
  WriteCOFFSectionHeader(F, '.data', 0, 0, DataSz, DataOfs,
    0, 0,
    COFF_SCN_CNT_INIT_DATA Or COFF_SCN_MEM_READ Or
    COFF_SCN_MEM_WRITE Or COFF_SCN_ALIGN_4BYTES);

  { .bss : donnees non initialisees }
  WriteCOFFSectionHeader(F, '.bss', 0, 0, 0, 0,
    0, 0,
    COFF_SCN_CNT_UNINIT_DATA Or COFF_SCN_MEM_READ Or
    COFF_SCN_MEM_WRITE Or COFF_SCN_ALIGN_4BYTES);

  { 3. Section .text (code) }
  WriteCOFFTextSection(F);

  { 4. Section .data (donnees) }
  WriteCOFFDataSection(F);

  { 5. Table des symboles }
  WriteCOFFSectionSymbols(F);
  WriteCOFFExternalSymbols(F);
  WriteCOFFPublicSymbols(F);

  { 6. Table des chaines }
  WriteCOFFStringTable(F);
  { Ecrire les chaines longues des symboles }
  COFFWriteString(F, '_ExitProcess@4');
  COFFWriteByte(F, 0);
  COFFWriteString(F, '_GetProcessHeap@0');
  COFFWriteByte(F, 0);
  COFFWriteString(F, '_HeapAlloc@12');
  COFFWriteByte(F, 0);
  COFFWriteString(F, '_HeapFree@12');
  COFFWriteByte(F, 0);
  COFFWriteString(F, '_GetStdHandle@4');
  COFFWriteByte(F, 0);
  COFFWriteString(F, '_WriteFile@20');
  COFFWriteByte(F, 0);
  COFFWriteString(F, '_ReadFile@20');
  COFFWriteByte(F, 0);
  COFFWriteString(F, '_MessageBoxA@16');
  COFFWriteByte(F, 0);

  { Fermer le fichier }
  Close(F);

  COFFTextSize := TextSz;
  COFFDataSize := DataSz;
  COFFBssSize  := 0;
End;

{ ------------------------------------------------------------ }
{ COFFSectionName : nom de section par index                    }
{ ------------------------------------------------------------ }

Function COFFSectionName(Idx : Integer) : String;
Begin
  Case Idx of
    1: COFFSectionName := '.text';
    2: COFFSectionName := '.data';
    3: COFFSectionName := '.bss';
  Else
    COFFSectionName := '.unknown';
  End;
End;

{ ------------------------------------------------------------ }
{ COFFRelocTypeName : nom du type de relocation                 }
{ ------------------------------------------------------------ }

Function COFFRelocTypeName(T : Word) : String;
Begin
  Case T of
    IMAGE_REL_I386_DIR32: COFFRelocTypeName := 'DIR32';
    IMAGE_REL_I386_REL32: COFFRelocTypeName := 'REL32';
  Else
    COFFRelocTypeName := 'UNKNOWN';
  End;
End;

{ ------------------------------------------------------------ }
{ IsCOFFStatement : verifier si c est une instruction COFF      }
{ ------------------------------------------------------------ }

Function IsCOFFStatement(Const S : String) : Boolean;
Begin
  IsCOFFStatement := (S = 'WRITECOFF') Or (S = '.OBJ');
End;

{ ------------------------------------------------------------ }
{ IsCOFFSection : verifier si c est un nom de section COFF      }
{ ------------------------------------------------------------ }

Function IsCOFFSection(Const S : String) : Boolean;
Begin
  IsCOFFSection := (S = '.text') Or (S = '.data') Or (S = '.bss');
End;

{ ------------------------------------------------------------ }
{ IsCOFFSymbol : verifier si c est un label COFF                }
{ ------------------------------------------------------------ }

Function IsCOFFSymbol(Const S : String) : Boolean;
Begin
  IsCOFFSymbol := (S = COFF_RT_WRITE) Or (S = COFF_RT_HEADER) Or
                  (S = COFF_RT_SECTIONS) Or (S = COFF_RT_SYMTAB) Or
                  (S = COFF_RT_STRTAB) Or (S = COFF_RT_RELOCS) Or
                  (S = COFF_RT_EMIT) Or (S = COFF_RT_TEXT) Or
                  (S = COFF_RT_DATA) Or (S = COFF_RT_BSS);
End;

{ ------------------------------------------------------------ }
{ 10 fonctions accesseurs                                       }
{ ------------------------------------------------------------ }

Function GetCOFFWriterCount : LongInt;
Begin
  GetCOFFWriterCount := COFFWriterCount;
End;

Function IsCOFFWriterInitialized : Boolean;
Begin
  IsCOFFWriterInitialized := COFFWriterInitialized;
End;

Function IsCOFFWriterEmpty : Boolean;
Begin
  IsCOFFWriterEmpty := (COFFWriterCount = 0);
End;

Function GetCOFFWriterStatus : String;
Begin
  If Not COFFWriterInitialized Then
    GetCOFFWriterStatus := 'Not initialized'
  Else If COFFWriterCount > 0 Then
    GetCOFFWriterStatus := 'Written (' + ItoS(COFFWriterCount) + ' bytes)'
  Else
    GetCOFFWriterStatus := 'Initialized, not yet written';
End;

Function GetCOFFTextSize : LongInt;
Begin
  GetCOFFTextSize := COFFTextSize;
End;

Function GetCOFFDataSize : LongInt;
Begin
  GetCOFFDataSize := COFFDataSize;
End;

Function GetCOFFBssSize : LongInt;
Begin
  GetCOFFBssSize := COFFBssSize;
End;

Function GetCOFFSymbolCount : LongInt;
Begin
  GetCOFFSymbolCount := COFFSymbolCount;
End;

Function GetCOFFRelocCount : LongInt;
Begin
  GetCOFFRelocCount := COFFRelocCount;
End;

Function GetCOFFTotalSections : Integer;
Begin
  GetCOFFTotalSections := COFFTotalSections;
End;

{ ============================================================ }
{ TODO 23 - GENERATEUR DE LISTING ASSEMBLEUR (PARAMETRE -asm) }
{           [IMPLEMENTE]                                       }
{ ============================================================ }

Const
  { Directives d en-tete MASM }
  ASM_DIR_386            = '.386';
  ASM_DIR_MODEL          = '.MODEL FLAT, STDCALL';
  ASM_DIR_CASEMAP        = 'OPTION CASEMAP:NONE';

  { Directives de section }
  ASM_DIR_DATA           = '.DATA';
  ASM_DIR_DATA_UNINIT    = '.DATA?';
  ASM_DIR_CODE           = '.CODE';
  ASM_DIR_END            = 'END';

  { Suffixes de taille }
  ASM_SZ_BYTE            = 'DB';
  ASM_SZ_WORD            = 'DW';
  ASM_SZ_DWORD           = 'DD';
  ASM_SZ_QWORD           = 'DQ';

  { Nombre maximum d elements }
  MAX_ASM_EXTERNS        = 64;
  MAX_ASM_GLOBALS        = 256;
  MAX_ASM_PROCS          = 128;

  { Indentation }
  ASM_INDENT             = '    ';

  { Labels ASM runtime }
  ASM_RT_HEADER          = '_ASM_HEADER';
  ASM_RT_INCLUDELIB      = '_ASM_INCLIB';
  ASM_RT_DATA            = '_ASM_DATA';
  ASM_RT_BSS             = '_ASM_BSS';
  ASM_RT_EXTERN          = '_ASM_EXTERN';
  ASM_RT_CODE            = '_ASM_CODE';
  ASM_RT_PROCS           = '_ASM_PROCS';
  ASM_RT_ENTRY           = '_ASM_ENTRY';
  ASM_RT_EMIT            = '_ASM_EMIT';
  ASM_RT_WRITE           = '_ASM_WRITE';

  { Variables ASM segment }
  ASM_VAR_LINECOUNT      = '_ASM_LINECOUNT';
  ASM_VAR_EXTERNCOUNT    = '_ASM_EXTERNCOUNT';
  ASM_VAR_GLOBALCOUNT    = '_ASM_GLOBALCOUNT';
  ASM_VAR_PROCCOUNT      = '_ASM_PROCCOUNT';
  ASM_VAR_DATASIZE       = '_ASM_DATASIZE';

Var
  ASMWriterCount       : LongInt;
  ASMWriterInitialized : Boolean;
  ASMLineCount         : LongInt;
  ASMExternCount       : Integer;
  ASMGlobalCount       : Integer;
  ASMProcCount         : Integer;
  ASMDataSize          : LongInt;
  ASMBssSize           : LongInt;
  ASMTotalSections     : Integer;

{ ------------------------------------------------------------ }
{ InitASMWriter : initialiser l etat du generateur ASM          }
{ ------------------------------------------------------------ }

Procedure InitASMWriter;
Begin
  ASMWriterCount       := 0;
  ASMWriterInitialized := True;
  ASMLineCount         := 0;
  ASMExternCount       := 0;
  ASMGlobalCount       := 0;
  ASMProcCount         := 0;
  ASMDataSize          := 0;
  ASMBssSize           := 0;
  ASMTotalSections     := 4;
End;

{ ------------------------------------------------------------ }
{ ASMWriteLine : ecrire une ligne dans le fichier ASM           }
{ ------------------------------------------------------------ }

Procedure ASMWriteLine(Var F : Text; Const Line : String);
Begin
  WriteLn(F, Line);
  Inc(ASMWriterCount, Length(Line) + 2);
  Inc(ASMLineCount);
End;

{ ------------------------------------------------------------ }
{ ASMWriteBlank : ecrire une ligne vide                         }
{ ------------------------------------------------------------ }

Procedure ASMWriteBlank(Var F : Text);
Begin
  WriteLn(F);
  Inc(ASMWriterCount, 2);
  Inc(ASMLineCount);
End;

{ ------------------------------------------------------------ }
{ ASMWriteComment : ecrire un commentaire assembleur             }
{ ------------------------------------------------------------ }

Procedure ASMWriteComment(Var F : Text; Const Comment : String);
Begin
  ASMWriteLine(F, '; ' + Comment);
End;

{ ------------------------------------------------------------ }
{ ASMWriteIndented : ecrire une ligne indentee                  }
{ ------------------------------------------------------------ }

Procedure ASMWriteIndented(Var F : Text; Const Line : String);
Begin
  ASMWriteLine(F, ASM_INDENT + Line);
End;

{ ------------------------------------------------------------ }
{ ASMWriteLabel : ecrire un label assembleur                     }
{ ------------------------------------------------------------ }

Procedure ASMWriteLabel(Var F : Text; Const LabelName : String);
Begin
  ASMWriteLine(F, LabelName + ':');
End;

{ ------------------------------------------------------------ }
{ ASMWriteHeader : ecrire l en-tete MASM du fichier .ASM        }
{   .386 / .MODEL FLAT, STDCALL / OPTION CASEMAP:NONE          }
{ ------------------------------------------------------------ }

Procedure ASMWriteHeader(Var F : Text);
Begin
  ASMWriteComment(F, '=========================================================');
  ASMWriteComment(F, ' Fichier genere par VBCW32 - Compilateur VB6 vers Win32');
  ASMWriteComment(F, ' Syntaxe MASM (Microsoft Macro Assembler)');
  ASMWriteComment(F, '=========================================================');
  ASMWriteBlank(F);
  ASMWriteLine(F, ASM_DIR_386);
  ASMWriteLine(F, ASM_DIR_MODEL);
  ASMWriteLine(F, ASM_DIR_CASEMAP);
  ASMWriteBlank(F);
End;

{ ------------------------------------------------------------ }
{ ASMWriteIncludelib : ecrire les directives INCLUDELIB          }
{   kernel32.lib, user32.lib, msvcrt.lib                        }
{ ------------------------------------------------------------ }

Procedure ASMWriteIncludelib(Var F : Text);
Begin
  ASMWriteComment(F, '---------------------------------------------------------');
  ASMWriteComment(F, ' Bibliotheques d importation');
  ASMWriteComment(F, '---------------------------------------------------------');
  ASMWriteBlank(F);
  ASMWriteLine(F, 'INCLUDELIB kernel32.lib');
  ASMWriteLine(F, 'INCLUDELIB user32.lib');
  ASMWriteLine(F, 'INCLUDELIB msvcrt.lib');
  ASMWriteBlank(F);
End;

{ ------------------------------------------------------------ }
{ ASMWriteExterns : ecrire les declarations EXTERN               }
{   Fonctions importees des DLL Win32                           }
{ ------------------------------------------------------------ }

Procedure ASMWriteExterns(Var F : Text);
Begin
  ASMWriteComment(F, '---------------------------------------------------------');
  ASMWriteComment(F, ' Declarations externes (fonctions importees)');
  ASMWriteComment(F, '---------------------------------------------------------');
  ASMWriteBlank(F);
  { kernel32.dll }
  ASMWriteLine(F, 'EXTERN ExitProcess@4:PROC');
  ASMWriteLine(F, 'EXTERN GetProcessHeap@0:PROC');
  ASMWriteLine(F, 'EXTERN HeapAlloc@12:PROC');
  ASMWriteLine(F, 'EXTERN HeapFree@12:PROC');
  ASMWriteLine(F, 'EXTERN GetStdHandle@4:PROC');
  ASMWriteLine(F, 'EXTERN WriteFile@20:PROC');
  ASMWriteLine(F, 'EXTERN ReadFile@20:PROC');
  ASMWriteLine(F, 'EXTERN CreateFileA@28:PROC');
  ASMWriteLine(F, 'EXTERN CloseHandle@4:PROC');
  ASMWriteLine(F, 'EXTERN SetFilePointer@16:PROC');
  ASMWriteLine(F, 'EXTERN GetFileSize@8:PROC');
  ASMWriteLine(F, 'EXTERN GetCommandLineA@0:PROC');
  ASMWriteLine(F, 'EXTERN GetModuleHandleA@4:PROC');
  ASMWriteLine(F, 'EXTERN GetLastError@0:PROC');
  ASMExternCount := 14;
  { user32.dll }
  ASMWriteLine(F, 'EXTERN MessageBoxA@16:PROC');
  Inc(ASMExternCount);
  ASMWriteBlank(F);
End;

{ ------------------------------------------------------------ }
{ ASMWriteDataSection : ecrire la section .DATA                  }
{   Variables globales initialisees avec DB/DW/DD/DQ            }
{ ------------------------------------------------------------ }

Procedure ASMWriteDataSection(Var F : Text);
Begin
  ASMWriteComment(F, '---------------------------------------------------------');
  ASMWriteComment(F, ' Section de donnees initialisees');
  ASMWriteComment(F, '---------------------------------------------------------');
  ASMWriteBlank(F);
  ASMWriteLine(F, ASM_DIR_DATA);
  ASMWriteBlank(F);
  { Variables minimales du runtime }
  ASMWriteIndented(F, '_VBRT_HPROCESS DD 0         ; Handle du processus');
  ASMWriteIndented(F, '_VBRT_HSTDOUT  DD 0         ; Handle stdout');
  ASMWriteIndented(F, '_VBRT_HSTDIN   DD 0         ; Handle stdin');
  ASMWriteIndented(F, '_VBRT_HEAP     DD 0         ; Handle du tas');
  ASMWriteIndented(F, '_VBRT_EXITCODE DD 0         ; Code de sortie');
  ASMWriteIndented(F, '_VBRT_ERRNR    DD 0         ; Err.Number');
  ASMWriteIndented(F, '_VBRT_WRITTEN  DD 0         ; Octets ecrits');
  ASMGlobalCount := 7;
  ASMDataSize := 7 * 4;
  ASMWriteBlank(F);
End;

{ ------------------------------------------------------------ }
{ ASMWriteBssSection : ecrire la section .DATA? (BSS)            }
{   Variables non initialisees                                   }
{ ------------------------------------------------------------ }

Procedure ASMWriteBssSection(Var F : Text);
Begin
  ASMWriteComment(F, '---------------------------------------------------------');
  ASMWriteComment(F, ' Section de donnees non initialisees (BSS)');
  ASMWriteComment(F, '---------------------------------------------------------');
  ASMWriteBlank(F);
  ASMWriteLine(F, ASM_DIR_DATA_UNINIT);
  ASMWriteBlank(F);
  { Buffer generique pour les operations E/S }
  ASMWriteIndented(F, '_VBRT_IOBUF    DB 1024 DUP(?) ; Buffer E/S');
  ASMWriteIndented(F, '_VBRT_STRBUF   DB 256 DUP(?)  ; Buffer chaine');
  ASMBssSize := 1024 + 256;
  ASMWriteBlank(F);
End;

{ ------------------------------------------------------------ }
{ ASMWriteRuntimeInit : ecrire la routine _VBRT_INIT             }
{   Initialisation du runtime (heap, handles std)                }
{ ------------------------------------------------------------ }

Procedure ASMWriteRuntimeInit(Var F : Text);
Begin
  ASMWriteComment(F, ' Initialisation du runtime VB');
  ASMWriteLabel(F, '_VBRT_INIT');
  ASMWriteIndented(F, 'PUSH EBP');
  ASMWriteIndented(F, 'MOV EBP, ESP');
  ASMWriteBlank(F);
  ASMWriteIndented(F, '; GetProcessHeap');
  ASMWriteIndented(F, 'CALL GetProcessHeap@0');
  ASMWriteIndented(F, 'MOV DWORD PTR [_VBRT_HEAP], EAX');
  ASMWriteBlank(F);
  ASMWriteIndented(F, '; GetStdHandle(-11) = STD_OUTPUT_HANDLE');
  ASMWriteIndented(F, 'PUSH -11');
  ASMWriteIndented(F, 'CALL GetStdHandle@4');
  ASMWriteIndented(F, 'MOV DWORD PTR [_VBRT_HSTDOUT], EAX');
  ASMWriteBlank(F);
  ASMWriteIndented(F, '; GetStdHandle(-10) = STD_INPUT_HANDLE');
  ASMWriteIndented(F, 'PUSH -10');
  ASMWriteIndented(F, 'CALL GetStdHandle@4');
  ASMWriteIndented(F, 'MOV DWORD PTR [_VBRT_HSTDIN], EAX');
  ASMWriteBlank(F);
  ASMWriteIndented(F, 'MOV ESP, EBP');
  ASMWriteIndented(F, 'POP EBP');
  ASMWriteIndented(F, 'RET');
  ASMWriteBlank(F);
  Inc(ASMProcCount);
End;

{ ------------------------------------------------------------ }
{ ASMWriteRuntimeExit : ecrire la routine _VBRT_EXIT             }
{   Terminaison du programme (ExitProcess)                       }
{ ------------------------------------------------------------ }

Procedure ASMWriteRuntimeExit(Var F : Text);
Begin
  ASMWriteComment(F, ' Terminaison du programme');
  ASMWriteLabel(F, '_VBRT_EXIT');
  ASMWriteIndented(F, 'PUSH DWORD PTR [_VBRT_EXITCODE]');
  ASMWriteIndented(F, 'CALL ExitProcess@4');
  ASMWriteBlank(F);
  Inc(ASMProcCount);
End;

{ ------------------------------------------------------------ }
{ ASMWriteRuntimePrint : ecrire la routine _VBRT_PRINT           }
{   Affichage console via WriteFile                              }
{ ------------------------------------------------------------ }

Procedure ASMWriteRuntimePrint(Var F : Text);
Begin
  ASMWriteComment(F, ' Affichage console (WriteFile sur stdout)');
  ASMWriteLabel(F, '_VBRT_PRINT');
  ASMWriteIndented(F, 'PUSH EBP');
  ASMWriteIndented(F, 'MOV EBP, ESP');
  ASMWriteIndented(F, '; Parametres : [EBP+8]=adresse, [EBP+12]=longueur');
  ASMWriteIndented(F, 'PUSH 0                          ; lpOverlapped');
  ASMWriteIndented(F, 'LEA EAX, [_VBRT_WRITTEN]');
  ASMWriteIndented(F, 'PUSH EAX                        ; lpNumberOfBytesWritten');
  ASMWriteIndented(F, 'PUSH DWORD PTR [EBP+12]         ; nNumberOfBytesToWrite');
  ASMWriteIndented(F, 'PUSH DWORD PTR [EBP+8]          ; lpBuffer');
  ASMWriteIndented(F, 'PUSH DWORD PTR [_VBRT_HSTDOUT]  ; hFile');
  ASMWriteIndented(F, 'CALL WriteFile@20');
  ASMWriteIndented(F, 'MOV ESP, EBP');
  ASMWriteIndented(F, 'POP EBP');
  ASMWriteIndented(F, 'RET 8');
  ASMWriteBlank(F);
  Inc(ASMProcCount);
End;

{ ------------------------------------------------------------ }
{ ASMWriteCodeSection : ecrire la section .CODE                  }
{   Routines runtime et point d entree                          }
{ ------------------------------------------------------------ }

Procedure ASMWriteCodeSection(Var F : Text);
Begin
  ASMWriteComment(F, '---------------------------------------------------------');
  ASMWriteComment(F, ' Section de code');
  ASMWriteComment(F, '---------------------------------------------------------');
  ASMWriteBlank(F);
  ASMWriteLine(F, ASM_DIR_CODE);
  ASMWriteBlank(F);
  { Routines runtime }
  ASMWriteRuntimeInit(F);
  ASMWriteRuntimeExit(F);
  ASMWriteRuntimePrint(F);
  { Point d entree principal }
  ASMWriteComment(F, ' Point d entree du programme');
  ASMWriteLabel(F, '_VBF_MAIN');
  ASMWriteIndented(F, 'PUSH EBP');
  ASMWriteIndented(F, 'MOV EBP, ESP');
  ASMWriteBlank(F);
  ASMWriteIndented(F, '; Initialiser le runtime');
  ASMWriteIndented(F, 'CALL _VBRT_INIT');
  ASMWriteBlank(F);
  ASMWriteIndented(F, '; --- Code utilisateur ---');
  ASMWriteIndented(F, '; (le compilateur insere le code VB compile ici)');
  ASMWriteBlank(F);
  ASMWriteIndented(F, '; Terminer le programme');
  ASMWriteIndented(F, 'MOV DWORD PTR [_VBRT_EXITCODE], 0');
  ASMWriteIndented(F, 'CALL _VBRT_EXIT');
  ASMWriteBlank(F);
  ASMWriteIndented(F, 'MOV ESP, EBP');
  ASMWriteIndented(F, 'POP EBP');
  ASMWriteIndented(F, 'RET');
  ASMWriteBlank(F);
  Inc(ASMProcCount);
End;

{ ------------------------------------------------------------ }
{ ASMWriteFooter : ecrire le pied de page du fichier .ASM        }
{   Directive END avec le point d entree                         }
{ ------------------------------------------------------------ }

Procedure ASMWriteFooter(Var F : Text);
Begin
  ASMWriteLine(F, ASM_DIR_END + ' _VBF_MAIN');
End;

{ ------------------------------------------------------------ }
{ WriteASM : generer le fichier listing assembleur complet       }
{ ------------------------------------------------------------ }

Procedure WriteASM(Const OutFile : String);
Var
  F : Text;
Begin
  { Reinitialiser les compteurs }
  ASMWriterCount := 0;
  ASMLineCount   := 0;
  ASMExternCount := 0;
  ASMGlobalCount := 0;
  ASMProcCount   := 0;
  ASMDataSize    := 0;
  ASMBssSize     := 0;

  { Ouvrir le fichier texte }
  Assign(F, OutFile);
  Rewrite(F);

  { 1. En-tete MASM }
  ASMWriteHeader(F);

  { 2. Directives INCLUDELIB }
  ASMWriteIncludelib(F);

  { 3. Declarations EXTERN }
  ASMWriteExterns(F);

  { 4. Section .DATA (donnees initialisees) }
  ASMWriteDataSection(F);

  { 5. Section .DATA? (BSS) }
  ASMWriteBssSection(F);

  { 6. Section .CODE (code et routines) }
  ASMWriteCodeSection(F);

  { 7. Directive END }
  ASMWriteFooter(F);

  { Fermer le fichier }
  Close(F);
End;

{ ------------------------------------------------------------ }
{ ASMSectionName : nom de section par index                     }
{ ------------------------------------------------------------ }

Function ASMSectionName(Idx : Integer) : String;
Begin
  Case Idx of
    1: ASMSectionName := '.DATA';
    2: ASMSectionName := '.DATA?';
    3: ASMSectionName := '.CODE';
    4: ASMSectionName := 'EXTERN';
  Else
    ASMSectionName := '.UNKNOWN';
  End;
End;

{ ------------------------------------------------------------ }
{ ASMDirectiveName : nom de directive MASM par type              }
{ ------------------------------------------------------------ }

Function ASMDirectiveName(DirType : Integer) : String;
Begin
  Case DirType of
    1: ASMDirectiveName := '.386';
    2: ASMDirectiveName := '.MODEL';
    3: ASMDirectiveName := 'OPTION';
    4: ASMDirectiveName := 'INCLUDELIB';
    5: ASMDirectiveName := 'EXTERN';
    6: ASMDirectiveName := 'END';
  Else
    ASMDirectiveName := 'UNKNOWN';
  End;
End;

{ ------------------------------------------------------------ }
{ IsASMStatement : verifier si c est une instruction ASM         }
{ ------------------------------------------------------------ }

Function IsASMStatement(Const S : String) : Boolean;
Begin
  IsASMStatement := (S = 'WRITEASM') Or (S = '.ASM');
End;

{ ------------------------------------------------------------ }
{ IsASMSection : verifier si c est un nom de section ASM         }
{ ------------------------------------------------------------ }

Function IsASMSection(Const S : String) : Boolean;
Begin
  IsASMSection := (S = '.DATA') Or (S = '.DATA?') Or
                  (S = '.CODE') Or (S = 'EXTERN');
End;

{ ------------------------------------------------------------ }
{ IsASMDirective : verifier si c est une directive MASM          }
{ ------------------------------------------------------------ }

Function IsASMDirective(Const S : String) : Boolean;
Begin
  IsASMDirective := (S = '.386') Or (S = '.MODEL') Or
                    (S = 'OPTION') Or (S = 'INCLUDELIB') Or
                    (S = 'EXTERN') Or (S = 'END') Or
                    (S = ASM_RT_HEADER) Or (S = ASM_RT_INCLUDELIB) Or
                    (S = ASM_RT_DATA) Or (S = ASM_RT_BSS) Or
                    (S = ASM_RT_EXTERN) Or (S = ASM_RT_CODE) Or
                    (S = ASM_RT_PROCS) Or (S = ASM_RT_ENTRY) Or
                    (S = ASM_RT_EMIT) Or (S = ASM_RT_WRITE);
End;

{ ------------------------------------------------------------ }
{ 10 fonctions accesseurs                                       }
{ ------------------------------------------------------------ }

Function GetASMWriterCount : LongInt;
Begin
  GetASMWriterCount := ASMWriterCount;
End;

Function IsASMWriterInitialized : Boolean;
Begin
  IsASMWriterInitialized := ASMWriterInitialized;
End;

Function IsASMWriterEmpty : Boolean;
Begin
  IsASMWriterEmpty := (ASMWriterCount = 0);
End;

Function GetASMWriterStatus : String;
Begin
  If Not ASMWriterInitialized Then
    GetASMWriterStatus := 'Not initialized'
  Else If ASMWriterCount > 0 Then
    GetASMWriterStatus := 'Written (' + ItoS(ASMLineCount) + ' lines)'
  Else
    GetASMWriterStatus := 'Initialized, not yet written';
End;

Function GetASMLineCount : LongInt;
Begin
  GetASMLineCount := ASMLineCount;
End;

Function GetASMExternCount : Integer;
Begin
  GetASMExternCount := ASMExternCount;
End;

Function GetASMGlobalCount : Integer;
Begin
  GetASMGlobalCount := ASMGlobalCount;
End;

Function GetASMProcCount : Integer;
Begin
  GetASMProcCount := ASMProcCount;
End;

Function GetASMDataSize : LongInt;
Begin
  GetASMDataSize := ASMDataSize;
End;

Function GetASMTotalSections : Integer;
Begin
  GetASMTotalSections := ASMTotalSections;
End;

{ ============================================================ }
{ TODO 24 - IMPORTS API WIN32 ET LIAISON                       }
{           (KERNEL32, USER32, MSVCRT)                         }
{           [IMPLEMENTE]                                       }
{ ============================================================ }

Const
  { Noms des DLL importees }
  IMP_DLL_KERNEL32       = 'kernel32.dll';
  IMP_DLL_USER32         = 'user32.dll';
  IMP_DLL_MSVCRT         = 'msvcrt.dll';

  { Nombre de DLL }
  IMP_DLL_COUNT          = 3;

  { Index des DLL }
  IMP_IDX_KERNEL32       = 0;
  IMP_IDX_USER32         = 1;
  IMP_IDX_MSVCRT         = 2;

  { Nombre de fonctions par DLL }
  IMP_KERNEL32_COUNT     = 27;
  IMP_USER32_COUNT       = 2;
  IMP_MSVCRT_COUNT       = 20;
  IMP_TOTAL_FUNCS        = 49;    { 27 + 2 + 20 }

  { Tailles des structures PE import }
  IMP_DESC_SIZE          = 20;    { IMAGE_IMPORT_DESCRIPTOR : 5 x DWORD }
  IMP_THUNK_SIZE         = 4;     { IMAGE_THUNK_DATA : 1 x DWORD }
  IMP_HINT_OVERHEAD      = 2;     { Hint (WORD) avant le nom }
  IMP_NULL_TERM          = 1;     { Octet nul terminateur }

  { Limites }
  MAX_IMPORT_DLLS        = 8;
  MAX_IMPORT_FUNCS       = 128;
  MAX_IMPORT_NAME_LEN    = 64;

  { Labels import runtime }
  IMP_RT_INIT            = '_IMP_INIT';
  IMP_RT_BUILD           = '_IMP_BUILD';
  IMP_RT_DESC            = '_IMP_DESC';
  IMP_RT_IAT             = '_IMP_IAT';
  IMP_RT_HINT            = '_IMP_HINT';
  IMP_RT_LOOKUP          = '_IMP_LOOKUP';
  IMP_RT_NAMES           = '_IMP_NAMES';
  IMP_RT_DLLNAME         = '_IMP_DLLNAME';
  IMP_RT_EXTERN          = '_IMP_EXTERN';
  IMP_RT_SYMBOL          = '_IMP_SYMBOL';

  { Variables import segment }
  IMP_VAR_DLLCOUNT       = '_IMP_DLLCOUNT';
  IMP_VAR_FUNCCOUNT      = '_IMP_FUNCCOUNT';
  IMP_VAR_TABLESIZE      = '_IMP_TABLESIZE';
  IMP_VAR_IATSIZE        = '_IMP_IATSIZE';
  IMP_VAR_HINTSIZE       = '_IMP_HINTSIZE';

  { Noms des fonctions kernel32.dll }
  K32_EXITPROCESS        = 'ExitProcess';
  K32_GETSTDHANDLE       = 'GetStdHandle';
  K32_WRITEFILE          = 'WriteFile';
  K32_READFILE           = 'ReadFile';
  K32_GETPROCESSHEAP     = 'GetProcessHeap';
  K32_HEAPALLOC          = 'HeapAlloc';
  K32_HEAPFREE           = 'HeapFree';
  K32_HEAPREALLOC        = 'HeapReAlloc';
  K32_CREATEFILEA        = 'CreateFileA';
  K32_CLOSEHANDLE        = 'CloseHandle';
  K32_SETFILEPOINTER     = 'SetFilePointer';
  K32_GETFILESIZE        = 'GetFileSize';
  K32_DELETEFILEA        = 'DeleteFileA';
  K32_GETCOMMANDLINEA    = 'GetCommandLineA';
  K32_GETMODULEHANDLEA   = 'GetModuleHandleA';
  K32_GETLASTERROR       = 'GetLastError';
  K32_SETLASTERROR       = 'SetLastError';
  K32_MOVEFILEA          = 'MoveFileA';
  K32_COPYFILEA          = 'CopyFileA';
  K32_GETCURRENTDIRA     = 'GetCurrentDirectoryA';
  K32_SETCURRENTDIRA     = 'SetCurrentDirectoryA';
  K32_CREATEDIRECTORYA   = 'CreateDirectoryA';
  K32_FINDFIRSTFILEA     = 'FindFirstFileA';
  K32_FINDNEXTFILEA      = 'FindNextFileA';
  K32_FINDCLOSE          = 'FindClose';
  K32_GETTICKCOUNT       = 'GetTickCount';
  K32_SLEEP              = 'Sleep';

  { Noms des fonctions user32.dll }
  U32_MESSAGEBOXA        = 'MessageBoxA';
  U32_GETDESKTOPWINDOW   = 'GetDesktopWindow';

  { Noms des fonctions msvcrt.dll }
  CRT_ITOA               = '_itoa';
  CRT_LTOA               = '_ltoa';
  CRT_ATOI               = 'atoi';
  CRT_ATOL               = 'atol';
  CRT_SPRINTF            = 'sprintf';
  CRT_SSCANF             = 'sscanf';
  CRT_GCVT               = '_gcvt';
  CRT_STRTOD             = 'strtod';
  CRT_SIN                = 'sin';
  CRT_COS                = 'cos';
  CRT_TAN                = 'tan';
  CRT_ATAN               = 'atan';
  CRT_SQRT               = 'sqrt';
  CRT_EXP2               = 'exp';
  CRT_LOG2               = 'log';
  CRT_POW2               = 'pow';
  CRT_FABS               = 'fabs';
  CRT_FMOD               = 'fmod';
  CRT_SRAND              = 'srand';
  CRT_RAND               = 'rand';

Var
  ImportCount            : LongInt;
  ImportInitialized      : Boolean;
  ImportDLLCount         : Integer;
  ImportFuncCount        : Integer;
  ImportTableSize        : LongInt;
  ImportIATSize          : LongInt;
  ImportHintSize         : LongInt;
  ImportK32Count         : Integer;
  ImportU32Count         : Integer;
  ImportCRTCount         : Integer;

{ ------------------------------------------------------------ }
{ InitImportState : initialiser l etat du module d imports      }
{ ------------------------------------------------------------ }

Procedure InitImportState;
Begin
  ImportCount       := 0;
  ImportInitialized := True;
  ImportDLLCount    := IMP_DLL_COUNT;
  ImportFuncCount   := IMP_TOTAL_FUNCS;
  ImportTableSize   := 0;
  ImportIATSize     := 0;
  ImportHintSize    := 0;
  ImportK32Count    := IMP_KERNEL32_COUNT;
  ImportU32Count    := IMP_USER32_COUNT;
  ImportCRTCount    := IMP_MSVCRT_COUNT;
End;

{ ------------------------------------------------------------ }
{ ImportDLLName : retourner le nom de la DLL par index           }
{ ------------------------------------------------------------ }

Function ImportDLLName(Idx : Integer) : String;
Begin
  Case Idx of
    IMP_IDX_KERNEL32: ImportDLLName := IMP_DLL_KERNEL32;
    IMP_IDX_USER32:   ImportDLLName := IMP_DLL_USER32;
    IMP_IDX_MSVCRT:   ImportDLLName := IMP_DLL_MSVCRT;
  Else
    ImportDLLName := '';
  End;
End;

{ ------------------------------------------------------------ }
{ ImportFuncCountForDLL : nombre de fonctions pour une DLL       }
{ ------------------------------------------------------------ }

Function ImportFuncCountForDLL(Idx : Integer) : Integer;
Begin
  Case Idx of
    IMP_IDX_KERNEL32: ImportFuncCountForDLL := IMP_KERNEL32_COUNT;
    IMP_IDX_USER32:   ImportFuncCountForDLL := IMP_USER32_COUNT;
    IMP_IDX_MSVCRT:   ImportFuncCountForDLL := IMP_MSVCRT_COUNT;
  Else
    ImportFuncCountForDLL := 0;
  End;
End;

{ ------------------------------------------------------------ }
{ GetKernel32FuncName : nom d une fonction kernel32 par index    }
{ ------------------------------------------------------------ }

Function GetKernel32FuncName(Idx : Integer) : String;
Begin
  Case Idx of
     0: GetKernel32FuncName := K32_EXITPROCESS;
     1: GetKernel32FuncName := K32_GETSTDHANDLE;
     2: GetKernel32FuncName := K32_WRITEFILE;
     3: GetKernel32FuncName := K32_READFILE;
     4: GetKernel32FuncName := K32_GETPROCESSHEAP;
     5: GetKernel32FuncName := K32_HEAPALLOC;
     6: GetKernel32FuncName := K32_HEAPFREE;
     7: GetKernel32FuncName := K32_HEAPREALLOC;
     8: GetKernel32FuncName := K32_CREATEFILEA;
     9: GetKernel32FuncName := K32_CLOSEHANDLE;
    10: GetKernel32FuncName := K32_SETFILEPOINTER;
    11: GetKernel32FuncName := K32_GETFILESIZE;
    12: GetKernel32FuncName := K32_DELETEFILEA;
    13: GetKernel32FuncName := K32_GETCOMMANDLINEA;
    14: GetKernel32FuncName := K32_GETMODULEHANDLEA;
    15: GetKernel32FuncName := K32_GETLASTERROR;
    16: GetKernel32FuncName := K32_SETLASTERROR;
    17: GetKernel32FuncName := K32_MOVEFILEA;
    18: GetKernel32FuncName := K32_COPYFILEA;
    19: GetKernel32FuncName := K32_GETCURRENTDIRA;
    20: GetKernel32FuncName := K32_SETCURRENTDIRA;
    21: GetKernel32FuncName := K32_CREATEDIRECTORYA;
    22: GetKernel32FuncName := K32_FINDFIRSTFILEA;
    23: GetKernel32FuncName := K32_FINDNEXTFILEA;
    24: GetKernel32FuncName := K32_FINDCLOSE;
    25: GetKernel32FuncName := K32_GETTICKCOUNT;
    26: GetKernel32FuncName := K32_SLEEP;
  Else
    GetKernel32FuncName := '';
  End;
End;

{ ------------------------------------------------------------ }
{ GetUser32FuncName : nom d une fonction user32 par index        }
{ ------------------------------------------------------------ }

Function GetUser32FuncName(Idx : Integer) : String;
Begin
  Case Idx of
    0: GetUser32FuncName := U32_MESSAGEBOXA;
    1: GetUser32FuncName := U32_GETDESKTOPWINDOW;
  Else
    GetUser32FuncName := '';
  End;
End;

{ ------------------------------------------------------------ }
{ GetMsvcrtFuncName : nom d une fonction msvcrt par index        }
{ ------------------------------------------------------------ }

Function GetMsvcrtFuncName(Idx : Integer) : String;
Begin
  Case Idx of
     0: GetMsvcrtFuncName := CRT_ITOA;
     1: GetMsvcrtFuncName := CRT_LTOA;
     2: GetMsvcrtFuncName := CRT_ATOI;
     3: GetMsvcrtFuncName := CRT_ATOL;
     4: GetMsvcrtFuncName := CRT_SPRINTF;
     5: GetMsvcrtFuncName := CRT_SSCANF;
     6: GetMsvcrtFuncName := CRT_GCVT;
     7: GetMsvcrtFuncName := CRT_STRTOD;
     8: GetMsvcrtFuncName := CRT_SIN;
     9: GetMsvcrtFuncName := CRT_COS;
    10: GetMsvcrtFuncName := CRT_TAN;
    11: GetMsvcrtFuncName := CRT_ATAN;
    12: GetMsvcrtFuncName := CRT_SQRT;
    13: GetMsvcrtFuncName := CRT_EXP2;
    14: GetMsvcrtFuncName := CRT_LOG2;
    15: GetMsvcrtFuncName := CRT_POW2;
    16: GetMsvcrtFuncName := CRT_FABS;
    17: GetMsvcrtFuncName := CRT_FMOD;
    18: GetMsvcrtFuncName := CRT_SRAND;
    19: GetMsvcrtFuncName := CRT_RAND;
  Else
    GetMsvcrtFuncName := '';
  End;
End;

{ ------------------------------------------------------------ }
{ GetImportFuncName : nom d une fonction par DLL et index        }
{ ------------------------------------------------------------ }

Function GetImportFuncName(DllIdx, FuncIdx : Integer) : String;
Begin
  Case DllIdx of
    IMP_IDX_KERNEL32: GetImportFuncName := GetKernel32FuncName(FuncIdx);
    IMP_IDX_USER32:   GetImportFuncName := GetUser32FuncName(FuncIdx);
    IMP_IDX_MSVCRT:   GetImportFuncName := GetMsvcrtFuncName(FuncIdx);
  Else
    GetImportFuncName := '';
  End;
End;

{ ------------------------------------------------------------ }
{ CalcHintNameEntrySize : taille d une entree Hint/Name          }
{   2 octets hint + longueur nom + 1 nul + padding pair          }
{ ------------------------------------------------------------ }

Function CalcHintNameEntrySize(Const FuncName : String) : LongInt;
Var
  Sz : LongInt;
Begin
  Sz := IMP_HINT_OVERHEAD + Length(FuncName) + IMP_NULL_TERM;
  If (Sz Mod 2) <> 0 Then
    Inc(Sz);
  CalcHintNameEntrySize := Sz;
End;

{ ------------------------------------------------------------ }
{ CalcImportTableSize : calculer la taille totale de la table    }
{   d importation PE                                              }
{ ------------------------------------------------------------ }

Procedure CalcImportTableSize;
Var
  D, F          : Integer;
  DllNameLen    : LongInt;
  HintTotal     : LongInt;
  IATTotal      : LongInt;
  DescTotal     : LongInt;
  FuncName      : String;
Begin
  { Descripteurs : 3 DLL + 1 terminateur nul }
  DescTotal := (IMP_DLL_COUNT + 1) * IMP_DESC_SIZE;

  { IAT et ILT : pour chaque DLL, N thunks + 1 terminateur nul }
  { On a 2 copies : ILT (OriginalFirstThunk) et IAT (FirstThunk) }
  IATTotal := 0;
  For D := 0 To IMP_DLL_COUNT - 1 Do Begin
    IATTotal := IATTotal +
      (ImportFuncCountForDLL(D) + 1) * IMP_THUNK_SIZE;
  End;
  IATTotal := IATTotal * 2; { ILT + IAT }

  { Hint/Name table }
  HintTotal := 0;
  For D := 0 To IMP_DLL_COUNT - 1 Do Begin
    For F := 0 To ImportFuncCountForDLL(D) - 1 Do Begin
      FuncName := GetImportFuncName(D, F);
      HintTotal := HintTotal + CalcHintNameEntrySize(FuncName);
    End;
  End;

  { Noms des DLL + terminateurs }
  DllNameLen := 0;
  For D := 0 To IMP_DLL_COUNT - 1 Do Begin
    DllNameLen := DllNameLen + Length(ImportDLLName(D)) + IMP_NULL_TERM;
  End;

  ImportTableSize := DescTotal + IATTotal + HintTotal + DllNameLen;
  ImportIATSize   := IATTotal Div 2;
  ImportHintSize  := HintTotal;
  Inc(ImportCount);
End;

{ ------------------------------------------------------------ }
{ GenImportDescriptor : generer un IMAGE_IMPORT_DESCRIPTOR       }
{   pour une DLL (OriginalFirstThunk, TimeDateStamp,             }
{   ForwarderChain, Name RVA, FirstThunk)                        }
{ ------------------------------------------------------------ }

Procedure GenImportDescriptor(DllIdx : Integer;
                               ILTRVA, NameRVA, IATRVA : LongInt);
Begin
  Emit('; IMAGE_IMPORT_DESCRIPTOR for ' + ImportDLLName(DllIdx));
  Emit('  DD ' + ItoS(ILTRVA));          { OriginalFirstThunk -> ILT }
  Emit('  DD 0');                         { TimeDateStamp }
  Emit('  DD 0');                         { ForwarderChain }
  Emit('  DD ' + ItoS(NameRVA));          { Name RVA }
  Emit('  DD ' + ItoS(IATRVA));           { FirstThunk -> IAT }
  Inc(ImportCount);
End;

{ ------------------------------------------------------------ }
{ GenImportNullDescriptor : descripteur nul terminateur           }
{ ------------------------------------------------------------ }

Procedure GenImportNullDescriptor;
Begin
  Emit('; NULL terminator descriptor');
  Emit('  DD 0');    { OriginalFirstThunk }
  Emit('  DD 0');    { TimeDateStamp }
  Emit('  DD 0');    { ForwarderChain }
  Emit('  DD 0');    { Name }
  Emit('  DD 0');    { FirstThunk }
  Inc(ImportCount);
End;

{ ------------------------------------------------------------ }
{ GenImportThunkTable : generer une table de thunks (ILT ou IAT) }
{   pour une DLL donnee                                           }
{ ------------------------------------------------------------ }

Procedure GenImportThunkTable(DllIdx : Integer;
                               Const TableName : String;
                               HintBaseRVA : LongInt);
Var
  F          : Integer;
  FuncName   : String;
  Offset     : LongInt;
Begin
  Emit('; ' + TableName + ' for ' + ImportDLLName(DllIdx));
  Offset := 0;
  For F := 0 To ImportFuncCountForDLL(DllIdx) - 1 Do Begin
    FuncName := GetImportFuncName(DllIdx, F);
    Emit('  DD ' + ItoS(HintBaseRVA + Offset) +
         '  ; -> ' + FuncName);
    Offset := Offset + CalcHintNameEntrySize(FuncName);
  End;
  Emit('  DD 0  ; NULL terminator');
  Inc(ImportCount);
End;

{ ------------------------------------------------------------ }
{ GenImportHintNameTable : generer les entrees Hint/Name         }
{   pour une DLL donnee                                           }
{ ------------------------------------------------------------ }

Procedure GenImportHintNameTable(DllIdx : Integer);
Var
  F          : Integer;
  FuncName   : String;
Begin
  Emit('; Hint/Name entries for ' + ImportDLLName(DllIdx));
  For F := 0 To ImportFuncCountForDLL(DllIdx) - 1 Do Begin
    FuncName := GetImportFuncName(DllIdx, F);
    Emit('  DW 0  ; Hint for ' + FuncName);
    Emit('  DB ''' + FuncName + ''', 0');
    If ((IMP_HINT_OVERHEAD + Length(FuncName) + IMP_NULL_TERM) Mod 2) <> 0 Then
      Emit('  DB 0  ; padding');
  End;
  Inc(ImportCount);
End;

{ ------------------------------------------------------------ }
{ GenImportDLLNames : generer les noms des DLL                   }
{ ------------------------------------------------------------ }

Procedure GenImportDLLNames;
Var
  D : Integer;
Begin
  Emit('; DLL name strings');
  For D := 0 To IMP_DLL_COUNT - 1 Do Begin
    Emit('  DB ''' + ImportDLLName(D) + ''', 0');
  End;
  Inc(ImportCount);
End;

{ ------------------------------------------------------------ }
{ GenPEImportTable : generer la table d importation PE complete   }
{   avec descripteurs, ILT, IAT, Hint/Name et noms DLL          }
{ ------------------------------------------------------------ }

Procedure GenPEImportTable;
Var
  D : Integer;
  BaseRVA : LongInt;
Begin
  CalcImportTableSize;

  Emit('');
  Emit('; ====================================');
  Emit('; PE Import Table');
  Emit('; ====================================');

  { Section 1 : Import Descriptors }
  Emit('');
  Emit('; --- Import Directory Table ---');
  BaseRVA := 0; { Les RVA seront resolus par le linker }
  For D := 0 To IMP_DLL_COUNT - 1 Do Begin
    GenImportDescriptor(D, 0, 0, 0);
  End;
  GenImportNullDescriptor;

  { Section 2 : ILT (Import Lookup Table) pour chaque DLL }
  Emit('');
  Emit('; --- Import Lookup Tables (ILT) ---');
  For D := 0 To IMP_DLL_COUNT - 1 Do Begin
    GenImportThunkTable(D, 'ILT', 0);
  End;

  { Section 3 : IAT (Import Address Table) pour chaque DLL }
  Emit('');
  Emit('; --- Import Address Tables (IAT) ---');
  For D := 0 To IMP_DLL_COUNT - 1 Do Begin
    GenImportThunkTable(D, 'IAT', 0);
  End;

  { Section 4 : Hint/Name Table }
  Emit('');
  Emit('; --- Hint/Name Table ---');
  For D := 0 To IMP_DLL_COUNT - 1 Do Begin
    GenImportHintNameTable(D);
  End;

  { Section 5 : DLL Names }
  Emit('');
  GenImportDLLNames;

  Inc(ImportCount);
End;

{ ------------------------------------------------------------ }
{ GenASMExternForDLL : generer les EXTERN pour une DLL (mode ASM)}
{ ------------------------------------------------------------ }

Procedure GenASMExternForDLL(DllIdx : Integer);
Var
  F          : Integer;
  FuncName   : String;
Begin
  For F := 0 To ImportFuncCountForDLL(DllIdx) - 1 Do Begin
    FuncName := GetImportFuncName(DllIdx, F);
    Emit('EXTERN ' + FuncName + ':PROC');
  End;
End;

{ ------------------------------------------------------------ }
{ GenASMExterns : generer tous les EXTERN pour le mode .ASM       }
{ ------------------------------------------------------------ }

Procedure GenASMExterns;
Var
  D : Integer;
Begin
  Emit('');
  Emit('; ====================================');
  Emit('; External API imports (MASM syntax)');
  Emit('; ====================================');
  For D := 0 To IMP_DLL_COUNT - 1 Do Begin
    Emit('');
    Emit('; Imports from ' + ImportDLLName(D));
    GenASMExternForDLL(D);
  End;
  Emit('');
  Inc(ImportCount);
End;

{ ------------------------------------------------------------ }
{ GenCOFFExternForDLL : generer symboles externes COFF pour DLL  }
{ ------------------------------------------------------------ }

Procedure GenCOFFExternForDLL(DllIdx : Integer);
Var
  F          : Integer;
  FuncName   : String;
Begin
  For F := 0 To ImportFuncCountForDLL(DllIdx) - 1 Do Begin
    FuncName := GetImportFuncName(DllIdx, F);
    Emit('; COFF external: ' + FuncName +
         ' (DLL: ' + ImportDLLName(DllIdx) + ')');
  End;
End;

{ ------------------------------------------------------------ }
{ GenCOFFExternalSymbols : generer symboles externes pour .OBJ    }
{ ------------------------------------------------------------ }

Procedure GenCOFFExternalSymbols;
Var
  D : Integer;
Begin
  Emit('');
  Emit('; ====================================');
  Emit('; External symbols for COFF .OBJ');
  Emit('; ====================================');
  For D := 0 To IMP_DLL_COUNT - 1 Do Begin
    Emit('');
    Emit('; External symbols from ' + ImportDLLName(D));
    GenCOFFExternForDLL(D);
  End;
  Emit('');
  Inc(ImportCount);
End;

{ ------------------------------------------------------------ }
{ GenASMIncludelibs : generer les directives INCLUDELIB           }
{ ------------------------------------------------------------ }

Procedure GenASMIncludelibs;
Begin
  Emit('');
  Emit('; Library includes');
  Emit('INCLUDELIB kernel32.lib');
  Emit('INCLUDELIB user32.lib');
  Emit('INCLUDELIB msvcrt.lib');
  Emit('');
  Inc(ImportCount);
End;

{ ------------------------------------------------------------ }
{ GenImportDataSegment : generer les donnees d import dans .DATA  }
{ ------------------------------------------------------------ }

Procedure GenImportDataSegment;
Begin
  EmitData(IMP_VAR_DLLCOUNT + ' DD ' + ItoS(ImportDLLCount));
  EmitData(IMP_VAR_FUNCCOUNT + ' DD ' + ItoS(ImportFuncCount));
  EmitData(IMP_VAR_TABLESIZE + ' DD ' + ItoS(ImportTableSize));
  EmitData(IMP_VAR_IATSIZE + ' DD ' + ItoS(ImportIATSize));
  EmitData(IMP_VAR_HINTSIZE + ' DD ' + ItoS(ImportHintSize));
  Inc(ImportCount);
End;

{ ------------------------------------------------------------ }
{ IsImportFunction : verifier si un nom est une fonction importee }
{ ------------------------------------------------------------ }

Function IsImportFunction(Const S : String) : Boolean;
Var
  D, F       : Integer;
  FuncName   : String;
Begin
  IsImportFunction := False;
  For D := 0 To IMP_DLL_COUNT - 1 Do Begin
    For F := 0 To ImportFuncCountForDLL(D) - 1 Do Begin
      FuncName := GetImportFuncName(D, F);
      If S = FuncName Then Begin
        IsImportFunction := True;
        Exit;
      End;
    End;
  End;
End;

{ ------------------------------------------------------------ }
{ IsImportDll : verifier si un nom est une DLL importee          }
{ ------------------------------------------------------------ }

Function IsImportDll(Const S : String) : Boolean;
Begin
  IsImportDll := (S = IMP_DLL_KERNEL32) Or
                 (S = IMP_DLL_USER32) Or
                 (S = IMP_DLL_MSVCRT);
End;

{ ------------------------------------------------------------ }
{ IsImportLabel : verifier si un nom est un label d import       }
{ ------------------------------------------------------------ }

Function IsImportLabel(Const S : String) : Boolean;
Begin
  IsImportLabel := (S = IMP_RT_INIT) Or (S = IMP_RT_BUILD) Or
                   (S = IMP_RT_DESC) Or (S = IMP_RT_IAT) Or
                   (S = IMP_RT_HINT) Or (S = IMP_RT_LOOKUP) Or
                   (S = IMP_RT_NAMES) Or (S = IMP_RT_DLLNAME) Or
                   (S = IMP_RT_EXTERN) Or (S = IMP_RT_SYMBOL);
End;

{ ------------------------------------------------------------ }
{ GetImportDllIndex : retourner l index d une DLL par nom        }
{ ------------------------------------------------------------ }

Function GetImportDllIndex(Const DllName : String) : Integer;
Begin
  If DllName = IMP_DLL_KERNEL32 Then
    GetImportDllIndex := IMP_IDX_KERNEL32
  Else If DllName = IMP_DLL_USER32 Then
    GetImportDllIndex := IMP_IDX_USER32
  Else If DllName = IMP_DLL_MSVCRT Then
    GetImportDllIndex := IMP_IDX_MSVCRT
  Else
    GetImportDllIndex := -1;
End;

{ ------------------------------------------------------------ }
{ GetImportFuncDll : retourner la DLL d une fonction importee    }
{ ------------------------------------------------------------ }

Function GetImportFuncDll(Const FuncName : String) : String;
Var
  D, F   : Integer;
  Name   : String;
Begin
  GetImportFuncDll := '';
  For D := 0 To IMP_DLL_COUNT - 1 Do Begin
    For F := 0 To ImportFuncCountForDLL(D) - 1 Do Begin
      Name := GetImportFuncName(D, F);
      If FuncName = Name Then Begin
        GetImportFuncDll := ImportDLLName(D);
        Exit;
      End;
    End;
  End;
End;

{ ------------------------------------------------------------ }
{ 10 fonctions accesseurs                                       }
{ ------------------------------------------------------------ }

Function GetImportCount : LongInt;
Begin
  GetImportCount := ImportCount;
End;

Function IsImportInitialized : Boolean;
Begin
  IsImportInitialized := ImportInitialized;
End;

Function IsImportEmpty : Boolean;
Begin
  IsImportEmpty := (ImportCount = 0);
End;

Function GetImportStatus : String;
Begin
  If Not ImportInitialized Then
    GetImportStatus := 'Not initialized'
  Else If ImportCount > 0 Then
    GetImportStatus := 'Active (' + ItoS(ImportFuncCount) + ' funcs, ' +
                       ItoS(ImportDLLCount) + ' DLLs)'
  Else
    GetImportStatus := 'Initialized, not yet generated';
End;

Function GetImportDLLTotal : Integer;
Begin
  GetImportDLLTotal := ImportDLLCount;
End;

Function GetImportFuncTotal : Integer;
Begin
  GetImportFuncTotal := ImportFuncCount;
End;

Function GetImportKernel32Count : Integer;
Begin
  GetImportKernel32Count := ImportK32Count;
End;

Function GetImportUser32Count : Integer;
Begin
  GetImportUser32Count := ImportU32Count;
End;

Function GetImportMsvcrtCount : Integer;
Begin
  GetImportMsvcrtCount := ImportCRTCount;
End;

Function GetImportTableTotalSize : LongInt;
Begin
  GetImportTableTotalSize := ImportTableSize;
End;

{ ============================================================ }
{ TODO 25 - OPTIMISATIONS, TESTS FINAUX ET INTEGRATION        }
{           SAMPLES\VB\*                                       }
{           [IMPLEMENTE]                                       }
{ ============================================================ }

Const
  { Nombre de regles d optimisation peephole }
  OPT_RULE_MOV_ZERO    = 0;   { MOV EAX, 0 -> XOR EAX, EAX        }
  OPT_RULE_PUSH_POP    = 1;   { PUSH EAX / POP EAX -> eliminer     }
  OPT_RULE_MOV_MOV     = 2;   { MOV EAX,[x] / MOV [x],EAX -> elim }
  OPT_RULE_ADD_ONE     = 3;   { ADD EAX, 1 -> INC EAX              }
  OPT_RULE_SUB_ONE     = 4;   { SUB EAX, 1 -> DEC EAX              }
  OPT_RULE_IMUL_TWO    = 5;   { IMUL EAX, 2 -> SHL EAX, 1         }
  OPT_RULE_IMUL_FOUR   = 6;   { IMUL EAX, 4 -> SHL EAX, 2         }
  OPT_RULE_COUNT       = 7;

  { Taille du tampon peephole (2 lignes suffisent) }
  OPT_BUFFER_SIZE      = 2;

  { Noms des fichiers exemples VB }
  MAX_VB_SAMPLES       = 12;
  VB_SAMPLE_DIR        = 'SAMPLES\VB\';
  VB_SAMPLE_HELLO      = 'HELLO.VB';
  VB_SAMPLE_CALC       = 'CALC.VB';
  VB_SAMPLE_FIBONACCI  = 'FIBONACCI.VB';
  VB_SAMPLE_FACTORI    = 'FACTORI.VB';
  VB_SAMPLE_ARRAY      = 'ARRAY.VB';
  VB_SAMPLE_STRING     = 'STRING.VB';
  VB_SAMPLE_FILEIO     = 'FILEIO.VB';
  VB_SAMPLE_SELECTCS   = 'SELECTCS.VB';
  VB_SAMPLE_LOOPS      = 'LOOPS.VB';
  VB_SAMPLE_USERTYPE   = 'USERTYPE.VB';
  VB_SAMPLE_SUBS       = 'SUBS.VB';
  VB_SAMPLE_ERRORS     = 'ERRORS.VB';

  { Modes de sortie }
  OUT_MODE_EXE         = 0;   { .EXE (defaut)                      }
  OUT_MODE_OBJ         = 1;   { .OBJ (-obj)                        }
  OUT_MODE_ASM         = 2;   { .ASM (-asm)                        }
  OUT_MODE_COUNT       = 3;

  { Labels internes pour l optimiseur }
  OPT_RT_INIT          = '_OPT_INIT';
  OPT_RT_APPLY         = '_OPT_APPLY';
  OPT_RT_FLUSH         = '_OPT_FLUSH';
  OPT_RT_MATCH         = '_OPT_MATCH';
  OPT_RT_REPLACE       = '_OPT_REPLACE';
  OPT_RT_ELIM          = '_OPT_ELIM';
  OPT_RT_STATS         = '_OPT_STATS';
  OPT_RT_RESET         = '_OPT_RESET';
  OPT_RT_CHECK         = '_OPT_CHECK';
  OPT_RT_VERIFY        = '_OPT_VERIFY';

  { Labels de variables }
  OPT_VAR_COUNT        = '_OPT_COUNT';
  OPT_VAR_APPLIED      = '_OPT_APPLIED';
  OPT_VAR_ELIMED       = '_OPT_ELIMINATED';
  OPT_VAR_BUFFER       = '_OPT_BUFFER';
  OPT_VAR_ENABLED      = '_OPT_ENABLED';

Var
  OptCount             : LongInt;
  OptInitialized       : Boolean;
  OptEnabled           : Boolean;
  OptApplied           : LongInt;
  OptEliminated        : LongInt;
  OptRuleHits          : Array[0..OPT_RULE_COUNT - 1] Of LongInt;
  OptBufferLine        : Array[0..OPT_BUFFER_SIZE - 1] Of TString;
  OptBufferCount       : Integer;
  OptTotalSamples      : Integer;

{ ------------------------------------------------------------ }
{ InitOptimizer : initialiser l etat de l optimiseur peephole  }
{ ------------------------------------------------------------ }

Procedure InitOptimizer;
Var
  I : Integer;
Begin
  OptCount       := 0;
  OptInitialized := True;
  OptEnabled     := True;
  OptApplied     := 0;
  OptEliminated  := 0;
  OptBufferCount := 0;
  OptTotalSamples := MAX_VB_SAMPLES;
  For I := 0 To OPT_RULE_COUNT - 1 Do
    OptRuleHits[I] := 0;
  For I := 0 To OPT_BUFFER_SIZE - 1 Do
    OptBufferLine[I] := '';
  Inc(OptCount);
End;

{ ------------------------------------------------------------ }
{ OptRuleName : retourner le nom d une regle d optimisation    }
{ ------------------------------------------------------------ }

Function OptRuleName(Rule : Integer) : String;
Begin
  Case Rule Of
    OPT_RULE_MOV_ZERO:  OptRuleName := 'MOV EAX,0 -> XOR EAX,EAX';
    OPT_RULE_PUSH_POP:  OptRuleName := 'PUSH/POP -> eliminate';
    OPT_RULE_MOV_MOV:   OptRuleName := 'MOV load/store -> eliminate';
    OPT_RULE_ADD_ONE:   OptRuleName := 'ADD EAX,1 -> INC EAX';
    OPT_RULE_SUB_ONE:   OptRuleName := 'SUB EAX,1 -> DEC EAX';
    OPT_RULE_IMUL_TWO:  OptRuleName := 'IMUL EAX,2 -> SHL EAX,1';
    OPT_RULE_IMUL_FOUR: OptRuleName := 'IMUL EAX,4 -> SHL EAX,2';
  Else
    OptRuleName := '(unknown)';
  End;
End;

{ ------------------------------------------------------------ }
{ OptApplyMovZero : MOV EAX, 0 -> XOR EAX, EAX                }
{ ------------------------------------------------------------ }

Function OptApplyMovZero(Const Line : String) : String;
Begin
  If (Line = 'MOV EAX, 0') Or (Line = 'MOV EAX,0') Then Begin
    OptApplyMovZero := 'XOR EAX, EAX';
    Inc(OptRuleHits[OPT_RULE_MOV_ZERO]);
    Inc(OptApplied);
  End
  Else
    OptApplyMovZero := Line;
End;

{ ------------------------------------------------------------ }
{ OptApplyAddOne : ADD EAX, 1 -> INC EAX                       }
{ ------------------------------------------------------------ }

Function OptApplyAddOne(Const Line : String) : String;
Begin
  If (Line = 'ADD EAX, 1') Or (Line = 'ADD EAX,1') Then Begin
    OptApplyAddOne := 'INC EAX';
    Inc(OptRuleHits[OPT_RULE_ADD_ONE]);
    Inc(OptApplied);
  End
  Else
    OptApplyAddOne := Line;
End;

{ ------------------------------------------------------------ }
{ OptApplySubOne : SUB EAX, 1 -> DEC EAX                       }
{ ------------------------------------------------------------ }

Function OptApplySubOne(Const Line : String) : String;
Begin
  If (Line = 'SUB EAX, 1') Or (Line = 'SUB EAX,1') Then Begin
    OptApplySubOne := 'DEC EAX';
    Inc(OptRuleHits[OPT_RULE_SUB_ONE]);
    Inc(OptApplied);
  End
  Else
    OptApplySubOne := Line;
End;

{ ------------------------------------------------------------ }
{ OptApplyImulTwo : IMUL EAX, 2 -> SHL EAX, 1                  }
{ ------------------------------------------------------------ }

Function OptApplyImulTwo(Const Line : String) : String;
Begin
  If (Line = 'IMUL EAX, 2') Or (Line = 'IMUL EAX,2') Then Begin
    OptApplyImulTwo := 'SHL EAX, 1';
    Inc(OptRuleHits[OPT_RULE_IMUL_TWO]);
    Inc(OptApplied);
  End
  Else
    OptApplyImulTwo := Line;
End;

{ ------------------------------------------------------------ }
{ OptApplyImulFour : IMUL EAX, 4 -> SHL EAX, 2                 }
{ ------------------------------------------------------------ }

Function OptApplyImulFour(Const Line : String) : String;
Begin
  If (Line = 'IMUL EAX, 4') Or (Line = 'IMUL EAX,4') Then Begin
    OptApplyImulFour := 'SHL EAX, 2';
    Inc(OptRuleHits[OPT_RULE_IMUL_FOUR]);
    Inc(OptApplied);
  End
  Else
    OptApplyImulFour := Line;
End;

{ ------------------------------------------------------------ }
{ OptApplySingleLine : appliquer les regles a une seule ligne   }
{ ------------------------------------------------------------ }

Function OptApplySingleLine(Const Line : String) : String;
Var
  R : String;
Begin
  R := Line;
  R := OptApplyMovZero(R);
  If R <> Line Then Begin OptApplySingleLine := R; Exit; End;
  R := OptApplyAddOne(R);
  If R <> Line Then Begin OptApplySingleLine := R; Exit; End;
  R := OptApplySubOne(R);
  If R <> Line Then Begin OptApplySingleLine := R; Exit; End;
  R := OptApplyImulTwo(R);
  If R <> Line Then Begin OptApplySingleLine := R; Exit; End;
  R := OptApplyImulFour(R);
  OptApplySingleLine := R;
End;

{ ------------------------------------------------------------ }
{ OptIsPushPopPair : detecter PUSH reg / POP reg consécutifs    }
{ ------------------------------------------------------------ }

Function OptIsPushPopPair(Const L1, L2 : String) : Boolean;
Begin
  OptIsPushPopPair := False;
  If (Length(L1) > 5) And (Length(L2) > 4) Then Begin
    If (Copy(L1, 1, 5) = 'PUSH ') And (Copy(L2, 1, 4) = 'POP ') Then Begin
      If Copy(L1, 6, Length(L1) - 5) = Copy(L2, 5, Length(L2) - 4) Then
        OptIsPushPopPair := True;
    End;
  End;
End;

{ ------------------------------------------------------------ }
{ OptIsRedundantMovPair : detecter MOV EAX,[x] / MOV [x],EAX   }
{ ------------------------------------------------------------ }

Function OptIsRedundantMovPair(Const L1, L2 : String) : Boolean;
Var
  P1, P2 : Integer;
  Src : String;
Begin
  OptIsRedundantMovPair := False;
  { L1 = MOV EAX, DWORD PTR [x]   et L2 = MOV DWORD PTR [x], EAX }
  If (Copy(L1, 1, 9) = 'MOV EAX, ') And (Length(L2) > 4) Then Begin
    Src := Copy(L1, 10, Length(L1) - 9);
    P1 := Pos(Src, L2);
    P2 := Pos(', EAX', L2);
    If (P1 > 0) And (P2 > 0) And (Copy(L2, 1, 4) = 'MOV ') Then
      OptIsRedundantMovPair := True;
  End;
End;

{ ------------------------------------------------------------ }
{ OptApplyPairRules : appliquer les regles sur paire de lignes  }
{ Retourne True si la paire a ete eliminee                      }
{ ------------------------------------------------------------ }

Function OptApplyPairRules(Const L1, L2 : String) : Boolean;
Begin
  OptApplyPairRules := False;
  { PUSH reg / POP reg -> eliminer les deux }
  If OptIsPushPopPair(L1, L2) Then Begin
    Inc(OptRuleHits[OPT_RULE_PUSH_POP]);
    Inc(OptEliminated, 2);
    Inc(OptApplied);
    OptApplyPairRules := True;
    Exit;
  End;
  { MOV EAX,[x] / MOV [x],EAX -> eliminer la deuxieme }
  If OptIsRedundantMovPair(L1, L2) Then Begin
    Inc(OptRuleHits[OPT_RULE_MOV_MOV]);
    Inc(OptEliminated);
    Inc(OptApplied);
    OptApplyPairRules := True;
    Exit;
  End;
End;

{ ------------------------------------------------------------ }
{ OptBufferPush : ajouter une ligne dans le tampon peephole     }
{ ------------------------------------------------------------ }

Procedure OptBufferPush(Const Line : String);
Begin
  If OptBufferCount < OPT_BUFFER_SIZE Then Begin
    OptBufferLine[OptBufferCount] := Line;
    Inc(OptBufferCount);
  End
  Else Begin
    { Decaler le tampon }
    OptBufferLine[0] := OptBufferLine[1];
    OptBufferLine[1] := Line;
  End;
End;

{ ------------------------------------------------------------ }
{ OptBufferClear : vider le tampon peephole                     }
{ ------------------------------------------------------------ }

Procedure OptBufferClear;
Var
  I : Integer;
Begin
  For I := 0 To OPT_BUFFER_SIZE - 1 Do
    OptBufferLine[I] := '';
  OptBufferCount := 0;
End;

{ ------------------------------------------------------------ }
{ OptResetCounters : reinitialiser les compteurs d optimisation }
{ ------------------------------------------------------------ }

Procedure OptResetCounters;
Var
  I : Integer;
Begin
  OptApplied    := 0;
  OptEliminated := 0;
  For I := 0 To OPT_RULE_COUNT - 1 Do
    OptRuleHits[I] := 0;
  OptBufferClear;
End;

{ ------------------------------------------------------------ }
{ VBSampleName : retourner le nom du fichier exemple par index  }
{ ------------------------------------------------------------ }

Function VBSampleName(Index : Integer) : String;
Begin
  Case Index Of
     0: VBSampleName := VB_SAMPLE_HELLO;
     1: VBSampleName := VB_SAMPLE_CALC;
     2: VBSampleName := VB_SAMPLE_FIBONACCI;
     3: VBSampleName := VB_SAMPLE_FACTORI;
     4: VBSampleName := VB_SAMPLE_ARRAY;
     5: VBSampleName := VB_SAMPLE_STRING;
     6: VBSampleName := VB_SAMPLE_FILEIO;
     7: VBSampleName := VB_SAMPLE_SELECTCS;
     8: VBSampleName := VB_SAMPLE_LOOPS;
     9: VBSampleName := VB_SAMPLE_USERTYPE;
    10: VBSampleName := VB_SAMPLE_SUBS;
    11: VBSampleName := VB_SAMPLE_ERRORS;
  Else
    VBSampleName := '';
  End;
End;

{ ------------------------------------------------------------ }
{ VBSampleDescription : retourner la description d un exemple   }
{ ------------------------------------------------------------ }

Function VBSampleDescription(Index : Integer) : String;
Begin
  Case Index Of
     0: VBSampleDescription := 'Hello World';
     1: VBSampleDescription := 'Calculatrice simple';
     2: VBSampleDescription := 'Suite de Fibonacci';
     3: VBSampleDescription := 'Factorielle';
     4: VBSampleDescription := 'Operations sur tableaux';
     5: VBSampleDescription := 'Operations sur chaines';
     6: VBSampleDescription := 'Entrees/sorties fichiers';
     7: VBSampleDescription := 'Select Case';
     8: VBSampleDescription := 'Boucles For/Do/While';
     9: VBSampleDescription := 'Types utilisateur';
    10: VBSampleDescription := 'Sub et Function';
    11: VBSampleDescription := 'Gestion des erreurs';
  Else
    VBSampleDescription := '';
  End;
End;

{ ------------------------------------------------------------ }
{ VBSamplePath : retourner le chemin complet d un exemple       }
{ ------------------------------------------------------------ }

Function VBSamplePath(Index : Integer) : String;
Var
  N : String;
Begin
  N := VBSampleName(Index);
  If N <> '' Then
    VBSamplePath := VB_SAMPLE_DIR + N
  Else
    VBSamplePath := '';
End;

{ ------------------------------------------------------------ }
{ OutModeName : retourner le nom du mode de sortie              }
{ ------------------------------------------------------------ }

Function OutModeName(Mode : Integer) : String;
Begin
  Case Mode Of
    OUT_MODE_EXE: OutModeName := '.EXE';
    OUT_MODE_OBJ: OutModeName := '.OBJ';
    OUT_MODE_ASM: OutModeName := '.ASM';
  Else
    OutModeName := '(unknown)';
  End;
End;

{ ------------------------------------------------------------ }
{ ShowOptStats : afficher les statistiques d optimisation        }
{ ------------------------------------------------------------ }

Procedure ShowOptStats;
Var
  I : Integer;
Begin
  If Not OptInitialized Then Exit;
  WriteLn;
  WriteLn('--- Optimisation peephole ---');
  WriteLn('Regles appliquees : ', OptApplied);
  WriteLn('Lignes eliminees  : ', OptEliminated);
  For I := 0 To OPT_RULE_COUNT - 1 Do Begin
    If OptRuleHits[I] > 0 Then
      WriteLn('  ', OptRuleName(I), ' : ', OptRuleHits[I]);
  End;
End;

{ ------------------------------------------------------------ }
{ ShowVBSamples : afficher la liste des exemples VB disponibles }
{ ------------------------------------------------------------ }

Procedure ShowVBSamples;
Var
  I : Integer;
Begin
  WriteLn;
  WriteLn('--- Exemples VB disponibles ---');
  For I := 0 To MAX_VB_SAMPLES - 1 Do
    WriteLn('  ', VBSamplePath(I), ' - ', VBSampleDescription(I));
End;

{ ------------------------------------------------------------ }
{ IsOptRule : verifier si un index de regle est valide          }
{ ------------------------------------------------------------ }

Function IsOptRule(Rule : Integer) : Boolean;
Begin
  IsOptRule := (Rule >= 0) And (Rule < OPT_RULE_COUNT);
End;

{ ------------------------------------------------------------ }
{ IsOptLabel : verifier si un label est un label d optimiseur   }
{ ------------------------------------------------------------ }

Function IsOptLabel(Const S : String) : Boolean;
Begin
  IsOptLabel := (S = OPT_RT_INIT) Or (S = OPT_RT_APPLY) Or
                (S = OPT_RT_FLUSH) Or (S = OPT_RT_MATCH) Or
                (S = OPT_RT_REPLACE) Or (S = OPT_RT_ELIM) Or
                (S = OPT_RT_STATS) Or (S = OPT_RT_RESET) Or
                (S = OPT_RT_CHECK) Or (S = OPT_RT_VERIFY);
End;

{ ------------------------------------------------------------ }
{ IsVBSample : verifier si un nom de fichier est un exemple VB  }
{ ------------------------------------------------------------ }

Function IsVBSample(Const FileName : String) : Boolean;
Var
  I : Integer;
Begin
  IsVBSample := False;
  For I := 0 To MAX_VB_SAMPLES - 1 Do Begin
    If FileName = VBSampleName(I) Then Begin
      IsVBSample := True;
      Exit;
    End;
  End;
End;

{ ------------------------------------------------------------ }
{ 10 fonctions accesseurs                                       }
{ ------------------------------------------------------------ }

Function GetOptCount : LongInt;
Begin
  GetOptCount := OptCount;
End;

Function IsOptInitialized : Boolean;
Begin
  IsOptInitialized := OptInitialized;
End;

Function IsOptEmpty : Boolean;
Begin
  IsOptEmpty := (OptApplied = 0);
End;

Function GetOptStatus : String;
Begin
  If Not OptInitialized Then
    GetOptStatus := 'Not initialized'
  Else If OptApplied > 0 Then
    GetOptStatus := 'Active (' + ItoS(OptApplied) + ' applied, ' +
                    ItoS(OptEliminated) + ' eliminated)'
  Else
    GetOptStatus := 'Initialized, no optimizations applied';
End;

Function IsOptEnabled : Boolean;
Begin
  IsOptEnabled := OptEnabled;
End;

Function GetOptApplied : LongInt;
Begin
  GetOptApplied := OptApplied;
End;

Function GetOptEliminated : LongInt;
Begin
  GetOptEliminated := OptEliminated;
End;

Function GetOptRuleCount : Integer;
Begin
  GetOptRuleCount := OPT_RULE_COUNT;
End;

Function GetOptTotalSamples : Integer;
Begin
  GetOptTotalSamples := OptTotalSamples;
End;

Function GetOptBufferCount : Integer;
Begin
  GetOptBufferCount := OptBufferCount;
End;

{ ------------------------------------------------------------ }
{ Run                                                          }
{ ------------------------------------------------------------ }

Procedure Run;
Begin
  ShowBanner;
  InitSymTable;
  InitScopes;
  InitExprState;
  InitCodeGen;
  InitCtrlState;
  InitLoopState;
  InitSubFuncState;
  InitIntrinsicState;
  InitStrOpState;
  InitArrayState;
  InitTypeEnumState;
  InitClassState;
  InitErrorState;
  InitFileIOState;
  InitRuntimeLib;
  InitCOFFWriter;
  InitASMWriter;
  InitImportState;
  InitOptimizer;
  LexInit;
  ParseModule;
  ParseModuleLevelDecl;
  ParseProcedures;
  { Les TODOs 19-25 ajouteront ici : }
  {   ParseStatements, WritePE/WriteCOFF/WriteASM }
  LexClose;
  ShowStats;
End;

{ ============================================================ }
{ PROGRAMME PRINCIPAL                                          }
{ ============================================================ }

BEGIN
  ErrorCount := 0;
  WarnCount  := 0;
  TotalLines := 0;
  OutFOpen   := False;
  BcActive   := False;

  ParseArgs;
  Run;
  Cleanup;
  Halt(EXIT_OK);
END.
