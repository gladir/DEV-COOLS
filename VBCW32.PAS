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

  TODO 08 - PARSEUR : EXPRESSIONS ARITHMETIQUES ET LOGIQUES (32 BITS) [A FAIRE]
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

  TODO 09 - GENERATION DE CODE : OPERATIONS ARITHMETIQUES 80386 [A FAIRE]
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
            Procedure ParseGoTo / ParseGoSub / ParseReturn
              GoTo label -> JMP label
              GoSub label -> CALL label / Return -> RET
              Labels numeriques (ligne) et labels nommes

  TODO 11 - PARSEUR : BOUCLES (FOR/NEXT, DO/LOOP, WHILE/WEND, FOR EACH) [A FAIRE]
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

  TODO 12 - PARSEUR : SUB ET FUNCTION (PROCEDURES ET FONCTIONS) [A FAIRE]
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

  TODO 13 - PARSEUR : FONCTIONS INTRINSEQUES (CHAINES, CONVERSION, MATH) [A FAIRE]
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

  TODO 14 - PARSEUR : OPERATIONS SUR CHAINES ET CONCATENATION [A FAIRE]
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

  TODO 15 - PARSEUR : TABLEAUX (DIM, REDIM, ERASE, LBOUND, UBOUND) [A FAIRE]
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

  TODO 16 - PARSEUR : TYPES UTILISATEUR (TYPE...END TYPE) ET ENUM [A FAIRE]
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

  TODO 17 - PARSEUR : MODULES DE CLASSE (CLASS, PROPERTY, METHOD) [A FAIRE]
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

  TODO 18 - PARSEUR : GESTION DES ERREURS (ON ERROR, RESUME, ERR) [A FAIRE]
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

  TODO 19 - PARSEUR : ENTREES/SORTIES FICHIERS (OPEN, CLOSE, PRINT#, INPUT#) [A FAIRE]
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

  TODO 20 - BIBLIOTHEQUE RUNTIME (CHAINES, CONVERSION, E/S VIA WIN32 API) [A FAIRE]
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
              Routines runtime (_VBRT_xxx)
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

  TODO 25 - OPTIMISATIONS, TESTS FINAUX ET INTEGRATION SAMPLES\VB\* [A FAIRE]
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

{ ------------------------------------------------------------ }
{ Run                                                          }
{ ------------------------------------------------------------ }

Procedure Run;
Begin
  ShowBanner;
  InitSymTable;
  InitScopes;
  LexInit;
  ParseModule;
  ParseModuleLevelDecl;
  { Les TODOs 08-25 ajouteront ici : }
  {   ParseStatements, Emit, WritePE/WriteCOFF/WriteASM }
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
