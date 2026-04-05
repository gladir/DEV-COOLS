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

  TODO 01 - INFRASTRUCTURE, OPTIONS ET CONSTANTES PE/COFF [A FAIRE]
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

  TODO 02 - TOKENISEUR VISUAL BASIC 6 (LEXER) [A FAIRE]
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

  TODO 03 - RECONNAISSANCE DES MOTS-CLES VISUAL BASIC 6 [A FAIRE]
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

  TODO 04 - TABLE DES SYMBOLES (32 BITS) [A FAIRE]
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

  TODO 05 - GESTION DES PORTEES (MODULE, SUB, FUNCTION, CLASS) [A FAIRE]
            Pile de portees : chaque portee maintient ses propres
              variables locales, un offset EBP courant, un label sortie
            Procedure EnterScope(kind: Integer; proc_idx: Integer)
            Procedure LeaveScope
            Function AllocLocalEbp(bytes: Integer): Integer
            Function CurrentEbpTop: Integer
            Portees supportees : SK_GLOBAL, SK_MODULE, SK_SUB,
              SK_FUNCTION, SK_PROPERTY, SK_CLASS, SK_WITH, SK_BLOCK
            Compteur d offset EBP pour allocation variables locales
            Offset EBP negatif pour locales [EBP-n]
            Offset EBP positif pour parametres [EBP+8], [EBP+12]...
            Convention STDCALL Win32 : parametres droite a gauche
            Variables Static : allouees en .DATA, pas en pile

  TODO 06 - PARSEUR : MODULE ET EN-TETE DU PROGRAMME [A FAIRE]
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

  TODO 07 - PARSEUR : DECLARATIONS (DIM, PUBLIC, PRIVATE, CONST, STATIC) [A FAIRE]
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
            Function ParseMulExpr: Integer    (* / /)
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
              Operateur Like avec motifs (*, ?, #, [charlist])
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
              Routines runtime (_VBRT_*)
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

Begin
 WriteLn('VBCW32 - Compilateur Visual Basic 6 vers Win32');
 WriteLn('Version 0.1 - En cours de developpement');
End.
