{ @author: Sylvain Maltais
  @created: 2026
  @version: 1.0
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
  @description: Compilateur Turbo Pascal vers assembleur 80386 pour Windows 32 bits
  @license: MIT
}

(* ============================================================
  TPCW32.PAS - Compilateur Turbo Pascal vers assembleur
  80386 pour Windows 32 bits
  Turbo Pascal / Free Pascal (-Mtp)
  Cible : MASM .386 / .MODEL FLAT, PE Win32

  Par defaut produit un fichier .EXE (PE Windows 32 bits).
  Avec le parametre -obj, produit uniquement un fichier .OBJ (COFF).
  Avec le parametre -asm, produit egalement un fichier .ASM lisible.
  Avec le parametre -dos16, produit un executable DOS 16 bits.

  Compilateur Turbo Pascal pour Windows 32 bits. Meme
  l instruction ASM avec de l assembleur 8086/8088 est
  traduite en assembleur 80386 de facon transparente.

  Les unites Crt, DOS, Graph, Graph3, Strings, Overlay,
  Printer, WinDOS, Turbo3, Objects sont supportees de
  facon native.

  Les Mem, MemW, MemL, Port, PortW sont supportes par
  emulation (Port[$60] -> lecture clavier via API Windows,
  lecture CMOS par Port/PortW, IN/OUT en ASM).

  L instruction MsDos de l unite DOS ou WinDOS, ainsi que
  INT 21h de l instruction ASM, emulent les appels des
  fonctions 00h, 01h, 02h, ... de l interruption 21h
  classique avec des appels a l API Windows equivalente.

  L instruction Intr ou l instruction INT d ASM supporte
  l interruption 10h, fonction 00h pour le changement de
  mode video.

  Il est possible d indiquer le numero de version du
  Turbo Pascal cible : 1, 2, 4, 5, 5.5 (tp55), 6, 7, 8.
  Par defaut c est la version 7.

  FEUILLE DE ROUTE - 25 TODOS
  ============================================================

  TODO 01 - INFRASTRUCTURE ET OPTIONS [IMPLEMENTE]
            TOptions : SrcFile, OutFile, Verbose, DebugMode, Warnings,
              AsmOutput, ObjOnly, Dos16Mode, TPVersion (1,2,4,5,55,6,7,8)
            ParseArgs : analyser argv
              source.pas [sortie.exe] [-v] [-d] [-w] [-asm] [-obj] [-dos16]
              [-tp1] [-tp2] [-tp4] [-tp5] [-tp55] [-tp6] [-tp7] [-tp8]
            FatalError, WarnMsg, EXIT_OK / EXIT_ERROR / EXIT_USAGE
            Detecter l extension .pas du fichier source
            Par defaut : sortie .EXE (PE Win32), TPVersion = 7
            Avec -obj : sortie .OBJ uniquement (COFF)
            Avec -asm : generer egalement un fichier .ASM lisible
            Avec -dos16 : generer un executable DOS 16 bits
            Programme principal : validation des arguments et appel Run
            Version, Date, aide en ligne (option -h)

  TODO 02 - LEXEUR (TOKENS TURBO PASCAL) [IMPLEMENTE]
            TTokenKind : TK_EOF, TK_INTEGER, TK_REAL, TK_STRING,
              TK_CHAR, TK_IDENT, TK_KEYWORD, TK_OP, TK_PUNCT
            LexInit, LexClose, LexNextToken, LexScanIdent, LexScanNumber
            LexScanString : chaine entre apostrophes 'abc'
              Concatenation implicite : 'ab'#13#10'cd'
              Caracteres speciaux : #nn (decimal), #$nn (hexadecimal)
            LexScanNumber : entiers decimaux, hexadecimaux ($FF),
              reels (3.14, 1.5E3), suffixes pour TP compatibilite
            Commentaires : accolades, paren-etoile et // (TP7+)
            Directives compilateur : $I+ $R- $IFDEF etc. entre accolades
            Mots-cles Turbo Pascal (selon TPVersion) :
              AND ARRAY ASM BEGIN CASE CONST CONSTRUCTOR
              DESTRUCTOR DIV DO DOWNTO ELSE END FILE FOR
              FUNCTION GOTO IF IMPLEMENTATION IN INHERITED
              INLINE INTERFACE LABEL MOD NIL NOT OBJECT OF
              OR PACKED PROCEDURE PROGRAM RECORD REPEAT SET
              SHL SHR STRING THEN TO TYPE UNIT UNTIL USES
              VAR WHILE WITH XOR
            Mots-cles supplementaires TP6+ : INHERITED, CONSTRUCTOR,
              DESTRUCTOR, OBJECT
            Mode debug -d : affichage de chaque token avec PrintToken

  TODO 03 - PREPROCESSEUR ET DIRECTIVES DE COMPILATION [IMPLEMENTE]
            Directives conditionnelles :
              $IFDEF symbole / $IFNDEF symbole / $ELSE / $ENDIF
              $IFOPT X+ : tester l etat d une option
              $DEFINE symbole / $UNDEF symbole
            Directives d inclusion :
              $I fichier.inc ou $INCLUDE fichier.inc
            Directives de commutation :
              $I+/$I- (verification I/O)
              $R+/$R- (verification de range)
              $B+/$B- (evaluation booleenne complete/court-circuit)
              $Q+/$Q- (verification overflow)
              $A+/$A- (alignement)
              $N+/$N- (coprocesseur numerique)
              $G+/$G- (generation code 80286)
              $X+/$X- (syntaxe etendue)
            Symboles predefinis selon TPVersion :
              VER70 (TP7), VER60 (TP6), VER55 (TP5.5), etc.
              MSDOS, CPU86, CPU87
              WIN32 (toujours defini dans TPCW32)

  TODO 04 - LITTERAUX ET CONSTANTES [IMPLEMENTE]
            Entiers decimaux : 0..2147483647 (LongInt 32 bits)
            Entiers hexadecimaux : $FF, $FFFF, $FFFFFFFF
            Reels : 3.14, 1.5E3, 2.7E-5 (tronques en entier)
            Caracteres : #65, #$41, 'A'
            Chaines : 'Hello World' -> pointeur vers donnees DATA
            Constantes typees : CONST x: Integer = 42
            Constantes ensemblistes : [1, 3..7, 10]
            NIL : constante pointeur nul -> EAX=0
            TRUE : constante booleenne -> EAX=1
            FALSE : constante booleenne -> EAX=0
            MaxInt, MaxLongInt : constantes predefinies
            Expressions constantes : evaluation a la compilation
              (operations arithmetiques, Ord, Chr, Sizeof, etc.)

  TODO 05 - TABLE DES SYMBOLES [IMPLEMENTE]
            TSymKind : SK_CONST, SK_TYPE, SK_VAR, SK_PARAM,
              SK_PROC, SK_FUNC, SK_FIELD, SK_METHOD, SK_UNIT,
              SK_LABEL, SK_PROPERTY
            TSymRec : Name, MangledName, Kind, TypeIdx, Offset,
              Scope, IsGlobal, IsExternal, UnitName
            SymAdd, SymFind, SymFindInScope, SymMangle
            CurScope : compteur de portee imbriquee (max MAX_SCOPE)
            SymEnterScope / SymLeaveScope : gestion des portees
            Qualificateurs d unite : Crt.ClrScr -> recherche dans Crt
            Enregistrement automatique des identificateurs predefinis :
              Integer, Word, Byte, Char, Boolean, String, Real,
              LongInt, ShortInt, Comp, Single, Double, Extended,
              Pointer, Text, PChar
            Procedures/fonctions predefinies :
              Write, WriteLn, Read, ReadLn, Str, Val, New, Dispose,
              Inc, Dec, Ord, Chr, Succ, Pred, Low, High, SizeOf,
              Abs, Sqr, Sqrt, Round, Trunc, Int, Frac, Sin, Cos,
              Ln, Exp, Pi, Halt, Exit, Break, Continue, Assigned,
              FillChar, Move, BlockRead, BlockWrite, Assign, Reset,
              Rewrite, Close, Eof, Eoln, IOResult, Seek, FilePos,
              FileSize, Rename, Erase, MkDir, RmDir, ChDir, GetDir

  TODO 06 - SYSTEME DE TYPES [IMPLEMENTE]
            TTypeKind : TYK_INTEGER (LongInt 32 bits signe),
              TYK_WORD (32 bits non signe), TYK_BYTE (8 bits),
              TYK_SHORTINT (8 bits signe), TYK_CHAR (8 bits),
              TYK_BOOLEAN (8 bits), TYK_STRING (ShortString),
              TYK_REAL (stub entier), TYK_SINGLE, TYK_DOUBLE,
              TYK_EXTENDED, TYK_COMP,
              TYK_POINTER (32 bits), TYK_PCHAR (ptr char),
              TYK_ARRAY, TYK_RECORD, TYK_SET, TYK_ENUM,
              TYK_FILE, TYK_TEXT, TYK_OBJECT, TYK_NIL,
              TYK_SUBRANGE, TYK_PROCVAR
            TypeTab, TypeInit : types primitifs Turbo Pascal
            TypeSizeof : LongInt=4, Word=4, Byte=1, Char=1,
              Boolean=1, ShortInt=1, Integer=4, Pointer=4,
              String[n]=n+1, Real/Single=4, Double=8
            Compatibilite de types : verification d affectation
            Conversion de types : typecast explicite Type(expr)
            Types ordinaux : Ord, Succ, Pred, Low, High
            Selon TPVersion : activer/desactiver certains types
              (TP1/TP2 : pas d objets, pas de PChar, etc.)

  TODO 07 - EMETTEUR DE CODE ASM 80386 [IMPLEMENTE]
            EmitOpen, EmitClose, EmitRaw, EmitLabel, EmitInstr
            EmitComment, EmitBlankLine
            LabelGen global (compteur unique _TPL_NNNNN)
            Prefixes ASM :
              _TPV_ (variable), _TPF_ (fonction/procedure),
              _TPK_ (constante chaine), _TPRT_ (runtime),
              _TPL_ (label interne), _TPA_ (tableau),
              _TPR_ (record), _TPE_ (enumeration),
              _TPU_ (unite)
            EmitHeader : .386 / .MODEL FLAT, STDCALL
              EXTRN pour les API Windows utilisees :
              ExitProcess, GetStdHandle, WriteFile, ReadFile,
              WriteConsoleA, ReadConsoleA, SetConsoleCursorPosition,
              GetConsoleScreenBufferInfo, SetConsoleTextAttribute,
              FillConsoleOutputCharacterA, FillConsoleOutputAttribute,
              GetConsoleMode, SetConsoleMode, GetProcessHeap,
              HeapAlloc, HeapFree, CreateFileA, CloseHandle,
              SetFilePointer, GetFileSize, DeleteFileA,
              CreateDirectoryA, RemoveDirectoryA,
              SetCurrentDirectoryA, GetCurrentDirectoryA,
              GetTickCount, Sleep, GetCommandLineA
            EmitDataSeg : .DATA + variables globales + constantes
            EmitCodeSeg : .CODE
            EmitProlog / EmitEpilog : PUSH EBP / MOV EBP,ESP ...
            Generation conditionnelle selon -asm (fichier .ASM)

  TODO 08 - SEGMENT DE DONNEES ET STATIQUES       [IMPLEMENTE]
            TDataRec : LblName, Kind (DK_DWORD/DK_BYTE/DK_STR/
              DK_ARRAY/DK_RECORD/DK_ZERO), IntVal, StrVal,
              ElemCount
            DataTab[0..MAX_DATA-1], DataCount
            DataAdd, DataAddStr, DataAddRecord
            DataAddGlobalVar, DataAddTypedConst, DataAddStaticVar
            ParseDataDecls : scanner TokenPool pour sections VAR
              et CONST globales
            Variables globales : entrees DD/DB dans .DATA
            Constantes typees : CONST x: Integer = 42 -> DD 42
            Chaines litterales : DB 'Hello',0 avec label _TPK_N
            Tables de methodes virtuelles (VMT) pour objets
            Variables de runtime :
              HSTDOUT DD 0, HSTDIN DD 0, HHEAP DD 0
              NUMBUF, INBUF, BYTESWR, BYTESRD, CRLF

  TODO 09 - VARIABLES ET AFFECTATIONS              [IMPLEMENTE]
            Variables globales : segment .DATA, acces par label _TPV_nom
            Variables locales : pile EBP, acces [EBP-offset]
            Parametres par valeur : copie sur pile
            Parametres par reference (VAR) : adresse sur pile
            Parametres constantes (CONST) : par reference, lecture seule
            Affectation := : ParseExpr + MOV destination, EAX
            Affectation de record : copie champ par champ ou REP MOVSD
            Affectation de string : copie avec longueur
            Variables non typees (Var F: File) : handle fichier

  TODO 10 - EXPRESSIONS PRIMAIRES                     [IMPLEMENTE]
            ParsePrimary : literal entier, literal chaine, ident,
              appel de procedure/fonction, typecast
            Acces qualifie d unite : Unit.Ident
            Acces champ : expr.champ -> offset dans record
            Acces index : expr[i] -> offset dans tableau
            Dereferencement : expr^ -> MOV EBX,EAX / MOV EAX,[EBX]
            Adresse : @expr -> LEA EAX, [expr]
            New(P) / Dispose(P) : allocation/liberation dynamique
            SizeOf(T) / SizeOf(V) : taille en octets -> EAX
            Ord(x), Chr(x), Succ(x), Pred(x), Low(T), High(T)
            Abs(x), Sqr(x), Round(x), Trunc(x)
            Inc(x[,n]), Dec(x[,n]) : increment/decrement

  TODO 11 - EXPRESSIONS BINAIRES ET PRECEDENCE     [IMPLEMENTE]
            Precedence (du plus fort au plus faible) :
              1. NOT, @, unaire +/-
              2. * / DIV MOD AND SHL SHR
              3. + - OR XOR
              4. = <> < > <= >= IN
            ParseExprPrec(MinPrec) : boucle de Pratt
            Arithmetique : ADD/SUB/IMUL/IDIV pour +, -, *, DIV
            MOD : IDIV -> resultat dans EDX (reste)
            Logique AND : court-circuit JZ vers branche fausse
            Logique OR : court-circuit JNZ vers branche vraie
            NOT : XOR EAX,1 (booleen) ou NOT EAX (bit a bit)
            SHL / SHR : SHL EAX,CL / SHR EAX,CL
            XOR : XOR EAX, operande
            Comparaison : CMP + Jcc (JE/JNE/JL/JG/JLE/JGE)
            Comparaison de chaines : CALL _TPRT_STRCMP -> drapeaux
            IN (ensemble) : BT [set], val ou decalage + AND
            Concatenation de chaines + : CALL _TPRT_CONCAT

  TODO 12 - ENTREES/SORTIES (Write / WriteLn / Read / ReadLn) [IMPLEMENTE]
            Write(args) : ecriture sur STDOUT via WriteFile/WriteConsoleA
              Write(I:5) : formatage avec largeur de champ
              Write(R:10:2) : reel avec largeur et decimales
              Write(S) : chaine, Write(C) : caractere, Write(B) : booleen
              Write(F, args) : ecriture dans fichier texte
            WriteLn(args) : Write(args) + CR+LF
            Read(args) : lecture depuis STDIN via ReadFile/ReadConsoleA
              Read(I) : entier, Read(C) : caractere, Read(S) : chaine
              Read(R) : reel, Read(F, args) : lecture depuis fichier
            ReadLn(args) : Read(args) + consommer jusqu a fin de ligne
            Str(N:W, S) : conversion nombre -> chaine
            Val(S, N, Code) : conversion chaine -> nombre
            Fichiers texte : Assign, Reset, Rewrite, Append, Close
            Fichiers types : File of T, Read(F, V), Write(F, V)
            Fichiers non types : BlockRead, BlockWrite
            IOResult : code d erreur derniere operation I/O

  TODO 13 - STRUCTURES DE CONTROLE                    [IMPLEMENTE]
            ParseIfStmt : IF cond THEN stmt [ELSE stmt]
              Emission TEST EAX,EAX / JZ LblElse, JMP LblEnd
            ParseCaseStmt : CASE expr OF
              val1: stmt; val2,val3: stmt; val4..val5: stmt;
              [ELSE stmt] END
              Emission CMP + JE pour chaque valeur, intervalle CMP+JB/JA
            ParseWhileStmt : WHILE cond DO stmt
              Labels : _TPL_WTEST_N, _TPL_WEND_N
            ParseRepeatStmt : REPEAT stmts UNTIL cond
              Labels : _TPL_RBEG_N, _TPL_RTEST_N
            ParseForStmt : FOR id := lo TO|DOWNTO hi DO stmt
              Variable de boucle, increment/decrement automatique
              Labels : _TPL_FTEST_N, _TPL_FINCR_N, _TPL_FEND_N
            ParseWithStmt : WITH expr DO stmt
              Alias temporaire vers record
            ParseGotoStmt : GOTO label
            Break : saut vers fin de boucle englobante
            Continue : saut vers test/increment de boucle englobante
            Exit : sortie de procedure/fonction courante
            Halt[(code)] : terminaison du programme

  TODO 14 - PROCEDURES ET FONCTIONS                   [IMPLEMENTE]
            ParseProcDecl / ParseFuncDecl
            Parametres par valeur, par reference (VAR),
              constantes (CONST), non types (Var X)
            Convention d appel : stdcall Win32 (ou cdecl selon option)
            Prologue : PUSH EBP / MOV EBP,ESP / SUB ESP, locals_size
            Epilogue : MOV ESP,EBP / POP EBP / RET n
            FUNCTION : resultat dans EAX (entier/pointeur)
              ou variable Result / nom_de_fonction
            Procedures imbriquees : acces au cadre englobant via
              lien statique (pointeur vers EBP du parent)
            Forward : declaration anticipee
            External : declaration de fonction externe (DLL)
            Inline : directive inline (expansion de code)
            Recursivite : supportee naturellement via pile
            Types proceduraux : variables de type procedure/function
              Appel indirect : CALL EAX

  TODO 15 - TABLEAUX, RECORDS, ENSEMBLES ET OBJETS    [IMPLEMENTE]
            ARRAY [lo..hi] OF T : tableau a bornes fixes
              Taille = (hi - lo + 1) * sizeof(T)
              Acces : offset calcule depuis base du tableau
              Multidimensionnel : ARRAY [a..b, c..d] OF T
            RECORD champ1: T1; champ2: T2; END
              Acces champ : offset fixe
              RECORD ... CASE tag OF ... END (variantes)
            SET OF T : ensemble (max 256 elements, 32 octets)
              Operations : + (union), * (intersection), - (difference)
              Test : IN, comparaison =, <>, <=, >=
            OBJECT (TP5.5+)
              Champs + Methodes (statiques et virtuelles)
              CONSTRUCTOR / DESTRUCTOR
              Heritage : OBJECT(Parent)
              VMT (Virtual Method Table) dans DATA
              Appel methode virtuelle : MOV EBX,[EAX] / CALL [EBX+offset]
              Self : premier parametre cache
            PACKED : versions compactees (PACKED RECORD, PACKED ARRAY)
            String[n] : chaine courte (1 octet longueur + n octets)

  TODO 16 - CHAINES DE CARACTERES                  [IMPLEMENTE]
            ShortString : String[n] (longueur max 255)
              Octet 0 = longueur, octets 1..n = caracteres
            PChar : pointeur vers chaine terminee par #0
            Concatenation + : CALL _TPRT_CONCAT
            Comparaison : CALL _TPRT_STRCMP -> drapeaux
            Copy(S, Pos, Len) : sous-chaine -> _TPRT_COPY
            Delete(S, Pos, Len) : suppression -> _TPRT_DELETE
            Insert(Src, Dst, Pos) : insertion -> _TPRT_INSERT
            Pos(SubStr, S) : recherche -> _TPRT_POS
            Length(S) : longueur -> CALL _TPRT_STRLEN
            Concat(S1, S2, ...) : concatenation multiple
            Str(N, S) / Val(S, N, Code) : conversions
            Upcase(Ch) : majuscule d un caractere
            Chr(N) / Ord(Ch) : conversions char <-> entier
            S[i] : acces direct au ieme caractere

  TODO 17 - INSTRUCTION ASM ET TRADUCTION 8086 -> 80386 [IMPLEMENTE]
            ParseAsmBlock : ASM ... END
            Traduction transparente des registres 8086 -> 80386 :
              AX -> EAX, BX -> EBX, CX -> ECX, DX -> EDX
              SI -> ESI, DI -> EDI, BP -> EBP, SP -> ESP
              AL, AH, BL, BH, CL, CH, DL, DH : inchanges (8 bits)
              CS, DS, ES, SS : ignores (modele FLAT Win32)
            Traduction des instructions :
              MOV, ADD, SUB, MUL, DIV, INC, DEC, CMP, TEST
              AND, OR, XOR, NOT, NEG, SHL, SHR, ROL, ROR
              PUSH, POP, CALL, RET, JMP, Jcc (JE, JNE, JL, etc.)
              LEA, XCHG, NOP, CLD, STD, REP MOVSB/MOVSW/MOVSD
              LOOP, LOOPZ, LOOPNZ -> equivalent 80386
              CBW -> CWDE, CWD -> CDQ
              LDS, LES -> remplacement par MOV registre 32 bits
              PUSHF/POPF -> PUSHFD/POPFD
            INT nn : traduction vers appel emule (voir TODO 21)
            IN / OUT : traduction vers emulation Port (voir TODO 22)
            Adressage : [BX+SI+disp] -> [EBX+ESI+disp] etc.
            Acces aux variables Pascal depuis ASM :
              MOV EAX, [variable] / MOV EAX, [EBP-offset]

  TODO 18 - UNITE CRT (EMULATION CONSOLE WINDOWS)
            ClrScr : FillConsoleOutputCharacterA + SetConsoleCursorPosition
            ClrEol : FillConsoleOutputCharacterA jusqu a fin de ligne
            GotoXY(X, Y) : SetConsoleCursorPosition
            WhereX / WhereY : GetConsoleScreenBufferInfo
            TextColor(C) / TextBackground(C) : SetConsoleTextAttribute
            TextAttr : variable d attribut courant
            HighVideo / LowVideo / NormVideo : attributs predefinis
            Window(X1, Y1, X2, Y2) : definir zone de texte active
            KeyPressed : PeekConsoleInput / GetNumberOfConsoleInputEvents
            ReadKey : ReadConsoleInput (lecture touche sans echo)
            Delay(ms) : Sleep(ms) API Windows
            Sound(Hz) / NoSound : Beep API Windows (ou stub)
            AssignCrt : associer fichier texte a la console
            DirectVideo : variable ignoree (pas d acces direct memoire)
            CheckBreak / CheckEOF / CheckSnow : variables de compatibilite

  TODO 19 - UNITE DOS ET WINDOS (EMULATION MSDOS / INT 21h)
            MsDos(Regs) : emulation des fonctions INT 21h
              Fonction 00h : terminaison -> ExitProcess
              Fonction 01h : lecture caractere -> ReadConsoleA
              Fonction 02h : ecriture caractere -> WriteConsoleA
              Fonction 09h : ecriture chaine $ -> WriteConsoleA
              Fonction 0Ah : lecture ligne -> ReadConsoleA
              Fonction 19h : disque courant -> GetCurrentDirectoryA
              Fonction 2Ah : date systeme -> GetLocalTime
              Fonction 2Ch : heure systeme -> GetLocalTime
              Fonction 30h : version DOS -> retourne version emulee
              Fonction 39h : creer repertoire -> CreateDirectoryA
              Fonction 3Ah : supprimer repertoire -> RemoveDirectoryA
              Fonction 3Bh : changer repertoire -> SetCurrentDirectoryA
              Fonction 3Ch : creer fichier -> CreateFileA
              Fonction 3Dh : ouvrir fichier -> CreateFileA
              Fonction 3Eh : fermer fichier -> CloseHandle
              Fonction 3Fh : lire fichier -> ReadFile
              Fonction 40h : ecrire fichier -> WriteFile
              Fonction 41h : supprimer fichier -> DeleteFileA
              Fonction 42h : deplacer pointeur -> SetFilePointer
              Fonction 4Ch : terminer programme -> ExitProcess
            DosVersion : retourne version configuree
            GetDate / GetTime / SetDate / SetTime
            GetFAttr / SetFAttr : GetFileAttributesA / SetFileAttributesA
            FindFirst / FindNext / FindClose : FindFirstFileA / FindNextFileA
            DiskFree / DiskSize : GetDiskFreeSpaceA
            GetEnv : GetEnvironmentVariableA
            FSearch / FExpand / FSplit : manipulation de chemins
            Exec(Path, CmdLine) : CreateProcessA
            DosExitCode : GetExitCodeProcess
            SwapVectors / GetIntVec / SetIntVec : stubs (non applicable Win32)
            Unite WinDOS : memes fonctions avec parametres de type PChar

  TODO 20 - UNITE GRAPH ET GRAPH3 (EMULATION GRAPHIQUE WINDOWS)
            InitGraph(Gd, Gm, Path) : creation fenetre graphique via
              CreateWindowExA, RegisterClassA, GetDC
              Emulation des modes : Detect, VGA, VGAHi (640x480x16)
            CloseGraph : destruction fenetre, ReleaseDC
            DetectGraph(Gd, Gm) : retourne VGA/VGAHi
            GraphResult / GraphErrorMsg : codes d erreur graphique
            PutPixel(X, Y, Color) : SetPixel via GDI
            GetPixel(X, Y) : GetPixel via GDI
            Line(X1, Y1, X2, Y2) : MoveToEx + LineTo
            Rectangle(X1, Y1, X2, Y2) : Rectangle GDI
            Bar(X1, Y1, X2, Y2) : FillRect GDI
            Bar3D(X1, Y1, X2, Y2, Depth, Top) : emulation 3D
            Circle(X, Y, R) : Ellipse GDI
            Arc(X, Y, SA, EA, R) : Arc GDI
            Ellipse(X, Y, SA, EA, XR, YR) : Ellipse GDI
            FillEllipse(X, Y, XR, YR) : Ellipse GDI rempli
            SetColor(C) / SetBkColor(C) : SelectObject(Pen/Brush)
            SetFillStyle(Pattern, Color) : CreateBrush
            SetLineStyle(Style, Pattern, Thick) : CreatePen
            OutTextXY(X, Y, S) : TextOutA GDI
            SetTextStyle(Font, Dir, Size) : CreateFontA
            GetMaxX / GetMaxY : taille de la zone graphique
            SetViewPort / SetActivePage / SetVisualPage : gestion pages
            ClearDevice : FillRect avec couleur de fond
            ImageSize / GetImage / PutImage : manipulation de bitmaps
            Unite Graph3 : compatibilite Turbo Pascal 3
              GraphColorMode, GraphMode, HiRes, HiResColor
              Draw, Plot, ColorTable, Palette

  TODO 21 - UNITES STRINGS, PRINTER, OVERLAY, TURBO3, OBJECTS
            Unite Strings (fonctions PChar / ASCIIZ) :
              StrCopy, StrCat, StrLen, StrComp, StrPos, StrScan,
              StrEnd, StrMove, StrNew, StrDispose, StrPas, StrPCopy,
              StrUpper, StrLower, StrLCopy, StrLCat, StrECopy,
              StrIComp, StrLIComp, StrRScan
            Unite Printer :
              Lst : fichier texte associe a l imprimante
              -> emulation : redirection vers fichier ou NUL
                 ou utilisation de l API Windows Printing si disponible
            Unite Overlay (TP6+) :
              OvrInit, OvrInitEMS, OvrSetBuf, OvrGetBuf,
              OvrClearBuf, OvrSetRetry, OvrGetReturnCode
              -> stubs (overlays non necessaires en Win32, memoire FLAT)
            Unite Turbo3 (compatibilite TP3) :
              GotoXY, ClrScr, ClrEol, LowVideo, NormVideo, Delay
              -> redirection vers implementations CRT
              Plot, Draw, ColorTable, GraphBackground, GraphColorMode,
              GraphMode, GraphWindow, HiRes, HiResColor, Palette
              -> redirection vers implementations Graph3
            Unite Objects (TP7) :
              TObject, TCollection, TStream, TDosStream,
              TBufStream, TEmsStream, TMemoryStream,
              TSortedCollection, TStringCollection, TStrCollection,
              TResourceFile, TResourceCollection, TStringList
              -> emulation des streams via API fichiers Windows

  TODO 22 - EMULATION MEM / MEMW / MEML / PORT / PORTW ET IN/OUT
            Mem[Seg:Ofs] : acces memoire octet
              -> emulation : tableau memoire simule ou acces direct
                 selon contexte (Mem[$0040:$0017] -> etat clavier
                 via GetKeyState / GetAsyncKeyState)
            MemW[Seg:Ofs] : acces memoire mot (16 bits)
              -> meme principe, lecture/ecriture 16 bits
            MemL[Seg:Ofs] : acces memoire double mot (32 bits)
              -> meme principe, lecture/ecriture 32 bits
            Port[$nn] : lecture port I/O octet
              Port[$60] : lecture clavier -> GetAsyncKeyState
              Port[$61] : controle haut-parleur -> Beep API
              Port[$70]/$71 : acces CMOS RTC
                -> GetLocalTime pour date/heure
              Port[$3F8]..$3FE : ports serie (COM1)
                -> emulation via CreateFile('COM1',...) API
              Autres ports : avertissement + NOP ou stub
            PortW[$nn] : lecture port I/O mot (16 bits)
              -> meme principe que Port mais 16 bits
            Instruction ASM IN AL, nn / IN AX, nn :
              -> traduction vers appel emulation Port correspondant
            Instruction ASM OUT nn, AL / OUT nn, AX :
              -> traduction vers appel emulation Port correspondant
            Generation de code :
              Port[$nn] en lecture -> CALL _TPRT_INPORT(EAX=port) -> AL/AX
              Port[$nn] en ecriture -> CALL _TPRT_OUTPORT(EAX=port, EDX=val)
              Mem[S:O] en lecture -> CALL _TPRT_READMEM(EAX=seg, EDX=ofs) -> AL/AX/EAX
              Mem[S:O] en ecriture -> CALL _TPRT_WRITEMEM(EAX=seg, EDX=ofs, ECX=val)

  TODO 23 - EMULATION INTERRUPTIONS (INT 10h, INT 21h, Intr)
            Procedure Intr(IntNo, Regs) de l unite DOS :
              Emulation des interruptions DOS/BIOS via API Windows
            INT 21h (DOS) : voir TODO 19 pour la table des fonctions
              -> routage vers _TPRT_INT21(AH=func, regs) -> API Windows
            INT 10h (Video BIOS) :
              Fonction 00h : changer mode video
                Mode 03h (texte 80x25) -> SetConsoleScreenBufferSize
                Mode 13h (graphique 320x200x256) -> InitGraph emule
                Autres modes -> avertissement + mode texte par defaut
              Fonction 02h : positionner curseur -> SetConsoleCursorPosition
              Fonction 03h : lire position curseur -> GetConsoleScreenBufferInfo
              Fonction 06h : defiler vers le haut -> ScrollConsoleScreenBuffer
              Fonction 07h : defiler vers le bas -> ScrollConsoleScreenBuffer
              Fonction 09h : ecrire caractere+attribut -> WriteConsoleOutputAttribute
              Fonction 0Eh : ecrire caractere (teletype) -> WriteConsoleA
              Fonction 0Fh : lire mode video -> retourne mode emule
              -> routage vers _TPRT_INT10(AH=func, regs) -> API Windows
            INT 16h (Clavier BIOS) :
              Fonction 00h : lire touche -> ReadConsoleInput
              Fonction 01h : touche disponible -> PeekConsoleInput
              -> routage vers _TPRT_INT16(AH=func, regs) -> API Windows
            INT 33h (Souris) :
              Fonction 00h : initialiser souris -> GetSystemMetrics/ShowCursor
              Fonction 03h : position/boutons -> GetCursorPos + GetAsyncKeyState
              -> routage vers _TPRT_INT33(AH=func, regs) -> API Windows
            Autres interruptions : avertissement + NOP

  TODO 24 - GENERATION PE/COFF (EXE/OBJ) ET MODE DOS 16 BITS
            Mode EXE (par defaut) :
              Generation directe d un fichier PE (Portable Executable)
              En-tete MZ DOS stub + en-tete PE + sections
              Section .text : code 80386
              Section .data : donnees initialisees
              Section .idata : table d importation (kernel32.dll,
                user32.dll, gdi32.dll)
              Alignement sections (4096 octets)
              Point d entree : _TPF_Main -> appel programme principal
              Import Address Table : resolution des API Windows
            Mode OBJ (-obj) :
              Generation d un fichier COFF (Common Object File Format)
              Symboles publics et externes
              Sections .text, .data, .bss
              Relocations : DIR32, REL32
              Compatible avec le linker Microsoft (LINK.EXE)
            Mode DOS 16 bits (-dos16) :
              Basculer vers generation code 8086 (16 bits)
              En-tete MZ DOS (pas de stub PE)
              .MODEL SMALL, .STACK 1024
              Registres 16 bits : AX, BX, CX, DX, SI, DI, BP, SP
              INT 21h natif (pas d emulation)
              Pas d emulation Windows (acces direct BIOS/DOS)
              Segments _TEXT / _DATA / _STACK

  TODO 25 - RUNTIME MINIMAL ET GENERATION FINALE
            Routines runtime (_TPRT_xxx) :
              _TPRT_PRINT(handle, ptr, len) : WriteFile API
              _TPRT_PRINTLN : _TPRT_PRINT + CR+LF
              _TPRT_READLN(handle, buf, max) : ReadFile API
              _TPRT_NUMTOSTR(EAX=n, EDI=buf) : entier -> ASCII (itoa)
              _TPRT_STRTONUM(ESI=str) : ASCII -> entier (atoi) -> EAX
              _TPRT_CONCAT(ESI=s1, EDI=s2) : concatenation ShortString
              _TPRT_STRCMP(ESI=s1, EDI=s2) : comparaison -> drapeaux
              _TPRT_COPY(ESI=src, EBX=pos, ECX=len) : sous-chaine
              _TPRT_DELETE, _TPRT_INSERT, _TPRT_POS : operations chaines
              _TPRT_NEW(ECX=taille) : HeapAlloc -> EAX=ptr
              _TPRT_DISPOSE(EAX=ptr) : HeapFree
              _TPRT_INPORT(EAX=port) : emulation lecture port -> AL/AX
              _TPRT_OUTPORT(EAX=port, EDX=val) : emulation ecriture port
              _TPRT_READMEM(EAX=seg, EDX=ofs) : emulation lecture memoire
              _TPRT_WRITEMEM(EAX=seg, EDX=ofs, ECX=val) : emulation ecriture
              _TPRT_INT21(AH=func) : emulation INT 21h
              _TPRT_INT10(AH=func) : emulation INT 10h
              _TPRT_INT16(AH=func) : emulation INT 16h
              _TPRT_INT33(AX=func) : emulation INT 33h
              _TPRT_HALT(EAX=code) : ExitProcess
            RuntimeEmitted : flag pour emettre le runtime une seule fois
            Generation finale :
              Run : pipeline complet LexInit -> Parse -> Emit -> Close
              Point d entree : _TPF_Main
                GetStdHandle(-11) -> HSTDOUT
                GetStdHandle(-10) -> HSTDIN
                GetProcessHeap -> HHEAP
                CALL _TPF_ProgramBody (corps du programme principal)
                PUSH 0 / CALL ExitProcess
              Fichiers SAMPLES\TURBOPASCAL\ a creer :
                hello.pas       (Write, WriteLn, variables, constantes)
                math.pas        (procedures, fonctions, recursion)
                control.pas     (IF, CASE, WHILE, FOR, REPEAT)
                strings.pas     (operations sur chaines, Copy, Pos, etc.)
                arrays.pas      (tableaux, records, ensembles)
                objects.pas     (objets TP5.5+, heritage, VMT)
                crt_demo.pas    (unite Crt, ClrScr, GotoXY, ReadKey)
                dos_demo.pas    (unite DOS, MsDos, FindFirst/FindNext)
                graph_demo.pas  (unite Graph, InitGraph, PutPixel, Line)
                asm_demo.pas    (instruction ASM, traduction 8086->80386)
                port_demo.pas   (Port, PortW, Mem, MemW emules)
                fileio.pas      (fichiers texte et types, BlockRead/Write)
              Smoke tests : TPCW32.EXE -v SAMPLES\TURBOPASCAL\*.pas

  ============================================================ *)

Program TPCW32;

{$IFDEF FPC}
  {$MODE TP}
  {$H-}
{$ENDIF}
{$I-}

{ ============================================================ }
{ TODO 01 - INFRASTRUCTURE ET OPTIONS                [IMPLEMENTE] }
{ ============================================================ }

Const
  TPCW32_VERSION = '0.1';
  TPCW32_DATE    = '2026';

  EXIT_OK    = 0;
  EXIT_ERROR = 1;
  EXIT_USAGE = 2;

  { Versions de Turbo Pascal supportees }
  TP_VER_1   = 1;
  TP_VER_2   = 2;
  TP_VER_4   = 4;
  TP_VER_5   = 5;
  TP_VER_55  = 55;   { 5.5 represente par 55 }
  TP_VER_6   = 6;
  TP_VER_7   = 7;
  TP_VER_8   = 8;
  TP_VER_DEFAULT = TP_VER_7;

Type
  TString = String;

  TOptions = Record
    SrcFile   : TString;   { fichier source (.pas)                }
    OutFile   : TString;   { fichier sortie (.exe, .obj)          }
    Verbose   : Boolean;   { -v : banniere et statistiques        }
    DebugMode : Boolean;   { -d : affichage de chaque token       }
    Warnings  : Boolean;   { -w : afficher les avertissements     }
    AsmOutput : Boolean;   { -asm : produire aussi un .ASM        }
    ObjOnly   : Boolean;   { -obj : produire seulement un .OBJ    }
    Dos16Mode : Boolean;   { -dos16 : generer un exe DOS 16 bits  }
    TPVersion : Integer;   { version TP cible (1..8, 55=5.5)      }
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

{ ------------------------------------------------------------ }
{ Fonctions utilitaires                                        }
{ ------------------------------------------------------------ }

Function IntToStr_(V : LongInt) : TString;
Var S : TString;
Begin
  Str(V, S);
  IntToStr_ := S;
End;

Function StrUpperCase(Const S : TString) : TString;
Var
  I   : Integer;
  Tmp : TString;
Begin
  Tmp := S;
  For I := 1 To Length(Tmp) Do
    If (Tmp[I] >= 'a') And (Tmp[I] <= 'z') Then
      Tmp[I] := Chr(Ord(Tmp[I]) - 32);
  StrUpperCase := Tmp;
End;

Function StrLowerCase(Const S : TString) : TString;
Var
  I   : Integer;
  Tmp : TString;
Begin
  Tmp := S;
  For I := 1 To Length(Tmp) Do
    If (Tmp[I] >= 'A') And (Tmp[I] <= 'Z') Then
      Tmp[I] := Chr(Ord(Tmp[I]) + 32);
  StrLowerCase := Tmp;
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
    ExtractExt := StrLowerCase(Copy(Path, LastDot,
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

{ Retourne une chaine representant la version TP }
Function TPVersionStr(V : Integer) : TString;
Begin
  If V = TP_VER_55 Then
    TPVersionStr := '5.5'
  Else
    TPVersionStr := IntToStr_(V);
End;

{ Retourne un rang sequentiel pour comparer les versions TP }
{ 1->1, 2->2, 4->3, 5->4, 55->5, 6->6, 7->7, 8->8 }
Function TPVersionOrd(V : Integer) : Integer;
Begin
  Case V Of
    1  : TPVersionOrd := 1;
    2  : TPVersionOrd := 2;
    4  : TPVersionOrd := 3;
    5  : TPVersionOrd := 4;
    55 : TPVersionOrd := 5;
    6  : TPVersionOrd := 6;
    7  : TPVersionOrd := 7;
    8  : TPVersionOrd := 8;
  Else
    TPVersionOrd := V;
  End;
End;

{ Retourne True si la version TP courante est >= MinVer }
Function TPVersionAtLeast(MinVer : Integer) : Boolean;
Begin
  TPVersionAtLeast := TPVersionOrd(Opts.TPVersion) >= TPVersionOrd(MinVer);
End;

{ ------------------------------------------------------------ }
{ FatalError / WarnMsg                                         }
{ ------------------------------------------------------------ }

Procedure FatalError(Const Msg : TString);
Begin
  WriteLn('TPCW32: FATAL: ', Msg);
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
  WriteLn('TPCW32: warning: ', Msg);
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
  Opts.AsmOutput := False;
  Opts.ObjOnly   := False;
  Opts.Dos16Mode := False;
  Opts.TPVersion := TP_VER_DEFAULT;
End;

{ ------------------------------------------------------------ }
{ ShowHelp                                                     }
{ ------------------------------------------------------------ }

Procedure ShowHelp;
Begin
  WriteLn('TPCW32 v', TPCW32_VERSION, ' (', TPCW32_DATE,
          ') - Compilateur Turbo Pascal vers 80386 (Windows PE 32 bits)');
  WriteLn('TPCW32 - Cette commande permet de lancer le compilateur Turbo ',
          'Pascal pour l''assembleur du microprocesseur 80386 (en executable ',
          'Windows 32 bits).');
  WriteLn;
  WriteLn('Syntaxe : TPCW32 <source.pas> [sortie] [options]');
  WriteLn;
  WriteLn('Sortie :');
  WriteLn('  Par defaut un .EXE (PE Windows 32 bits)');
  WriteLn('  -obj           Produire seulement un fichier .OBJ (COFF)');
  WriteLn('  -asm           Produire egalement un fichier .ASM lisible');
  WriteLn('  -dos16         Produire un executable DOS 16 bits');
  WriteLn;
  WriteLn('Version Turbo Pascal cible :');
  WriteLn('  -tp1           Turbo Pascal 1');
  WriteLn('  -tp2           Turbo Pascal 2');
  WriteLn('  -tp4           Turbo Pascal 4');
  WriteLn('  -tp5           Turbo Pascal 5');
  WriteLn('  -tp55          Turbo Pascal 5.5');
  WriteLn('  -tp6           Turbo Pascal 6');
  WriteLn('  -tp7           Turbo Pascal 7 (defaut)');
  WriteLn('  -tp8           Turbo Pascal 8');
  WriteLn;
  WriteLn('General :');
  WriteLn('  -v             Mode verbeux (banniere + statistiques)');
  WriteLn('  -d             Debug tokens (affiche chaque token)');
  WriteLn('  -w             Afficher les avertissements');
  WriteLn('  -h, --help, /? Afficher cette aide');
  WriteLn;
  WriteLn('Exemples :');
  WriteLn('  TPCW32 hello.pas');
  WriteLn('  TPCW32 hello.pas hello.exe -v');
  WriteLn('  TPCW32 main.pas -asm -tp7');
  WriteLn('  TPCW32 old.pas -tp4 -dos16');
  WriteLn('  TPCW32 program.pas -obj -w');
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
      Opts.AsmOutput := True
    Else If Arg = '-obj' Then
      Opts.ObjOnly := True
    Else If Arg = '-dos16' Then
      Opts.Dos16Mode := True
    Else If Arg = '-tp1' Then
      Opts.TPVersion := TP_VER_1
    Else If Arg = '-tp2' Then
      Opts.TPVersion := TP_VER_2
    Else If Arg = '-tp4' Then
      Opts.TPVersion := TP_VER_4
    Else If Arg = '-tp5' Then
      Opts.TPVersion := TP_VER_5
    Else If Arg = '-tp55' Then
      Opts.TPVersion := TP_VER_55
    Else If Arg = '-tp6' Then
      Opts.TPVersion := TP_VER_6
    Else If Arg = '-tp7' Then
      Opts.TPVersion := TP_VER_7
    Else If Arg = '-tp8' Then
      Opts.TPVersion := TP_VER_8
    Else If (Length(Arg) > 0) And (Arg[1] = '-') Then
      FatalError('Option inconnue: ' + Arg)
    Else
    Begin
      { Argument positionnel : fichier source ou sortie }
      If Opts.SrcFile = '' Then
        Opts.SrcFile := Arg
      Else If Opts.OutFile = '' Then
        Opts.OutFile := Arg
      Else
        FatalError('Argument inattendu: ' + Arg);
    End;

    Inc(I);
  End;

  { Validation : fichier source requis }
  If Opts.SrcFile = '' Then
  Begin
    WriteLn('TPCW32: fichier source manquant');
    ShowHelp;
  End;

  { Verifier l extension .pas }
  Ext := ExtractExt(Opts.SrcFile);
  If Ext <> '.pas' Then
    WarnMsg('extension attendue .pas, trouvee: ' + Ext);

  { -obj et -dos16 sont mutuellement exclusifs }
  If Opts.ObjOnly And Opts.Dos16Mode Then
    FatalError('-obj et -dos16 sont mutuellement exclusifs');

  { Fichier de sortie par defaut }
  If Opts.OutFile = '' Then
  Begin
    If Opts.ObjOnly Then
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
  WriteLn('TPCW32 v', TPCW32_VERSION, ' (', TPCW32_DATE,
          ') - Compilateur Turbo Pascal -> 80386 PE Win32');
  WriteLn('Source   : ', Opts.SrcFile);
  WriteLn('Sortie   : ', Opts.OutFile);
  If Opts.AsmOutput Then
    WriteLn('ASM      : ', ReplaceExt(Opts.OutFile, '.asm'));
  WriteLn('TP cible : ', TPVersionStr(Opts.TPVersion));
  If Opts.Dos16Mode Then
    WriteLn('Mode     : DOS 16 bits');
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
{ TODO 02 - LEXEUR (TOKENS TURBO PASCAL)          [IMPLEMENTE] }
{ ============================================================ }

Const
  MAX_STR = 255;

Type
  TTokenKind = (
    TK_EOF,           { fin de fichier                       }
    TK_INTEGER,       { litteral entier 42 $FF               }
    TK_REAL,          { litteral reel 3.14 1.5E3             }
    TK_STRING,        { litteral chaine 'hello'              }
    TK_CHAR,          { litteral caractere #65 #$41          }
    TK_IDENT,         { identificateur (non-mot-cle)         }
    TK_KEYWORD,       { mot-cle Pascal reconnu               }
    TK_OP,            { operateur := + - * / = <> < > etc.   }
    TK_PUNCT          { ponctuation ; , ( ) [ ] . ..         }
  );

  TToken = Record
    Kind     : TTokenKind;
    Val      : TString;      { valeur textuelle brute             }
    IntVal   : LongInt;      { valeur entiere (TK_INTEGER/CHAR)   }
    RealVal  : Real;         { valeur reelle (TK_REAL)            }
    Line     : Integer;      { ligne source (1-base)              }
    Col      : Integer;      { colonne source (1-base)            }
  End;

Var
  { Lexeur }
  LexSrcF   : Text;          { handle du fichier source           }
  LexOpened : Boolean;        { fichier ouvert ?                   }
  LexLine   : TString;       { ligne courante                     }
  LexLineNo : Integer;        { numero de ligne courante           }
  LexColNo  : Integer;        { colonne courante dans LexLine      }
  LexEOF    : Boolean;        { fin de fichier atteinte ?          }
  CurToken  : TToken;         { token courant                      }

  { TODO 03 : Directives et inclusions }
  DefineTab      : Array[0..63] Of TString;
  DefineCount    : Integer;
  IncSavedFName  : Array[0..7] Of TString;
  IncSavedLine   : Array[0..7] Of TString;
  IncSavedLineNo : Array[0..7] Of Integer;
  IncSavedColNo  : Array[0..7] Of Integer;
  IncSavedEOF    : Array[0..7] Of Boolean;
  IncTop         : Integer;
  LexSrcFName    : TString;
  OptIO          : Boolean;
  OptRange       : Boolean;
  OptBoolEval    : Boolean;
  OptOverflow    : Boolean;
  OptAlign       : Boolean;
  OptNCoprocessor: Boolean;
  OptGen286      : Boolean;
  OptExtSyntax   : Boolean;

{ Forward declarations TODO 03 }
Procedure LexHandleDollarDirective; Forward;
Procedure IncludePop; Forward;

{ ============================================================ }
{ TODO 04 - LITTERAUX ET CONSTANTES               [IMPLEMENTE] }
{ ============================================================ }

Const
  MAX_DATA   = {$IFDEF FPC}512{$ELSE}128{$ENDIF};
  MAX_TOKENS = {$IFDEF FPC}16384{$ELSE}4096{$ENDIF};

  { Prefixes de mangling pour les labels generes }
  TP_STR_PFX  = '_TPK_';   { constantes chaine                    }
  TP_VAR_PFX  = '_TPV_';   { variables                            }
  TP_LBL_PFX  = '_TPL_';   { labels internes                      }
  TP_RT_PFX   = '_TPRT_';  { routines runtime                     }
  TP_STA_PFX  = '_TPST_';  { variables statiques                  }
  TP_ARR_PFX  = '_TPA_';   { tableaux                             }
  TP_REC_PFX  = '_TPR_';   { records                              }
  TP_ENUM_PFX = '_TPE_';   { enumerations                         }
  TP_UNIT_PFX = '_TPU_';   { unites                               }

  { Table des tailles de types Turbo Pascal (Win32, 32 bits) }
  MAX_TP_TYPE_SIZES = 18;

Type
  { Types d entrees dans le pool de donnees }
  TDataKind = (
    DK_STR,     { chaine ASCIIZ (DB 'xxx',0)                         }
    DK_DWORD,   { valeur 32 bits (DD nnn)                             }
    DK_BYTE,    { valeur 8 bits (DB nnn)                              }
    DK_ARRAY,   { tableau (DB ElemCount*ElemSize DUP(0))              }
    DK_RES,     { espace reserve (DB Size DUP(0))                     }
    DK_STRUCT,  { structure/record (DB Size DUP(0))                   }
    DK_ZERO     { espace initialise a zero (DB Size DUP(0))          }
  );

  { Un enregistrement du pool de donnees }
  TDataRec = Record
    LblName   : TString;    { label ASM (ex: _TPK_1, _TPV_x)         }
    Kind      : TDataKind;  { type de donnee                           }
    IntVal    : LongInt;     { valeur entiere (pour DK_DWORD, DK_BYTE) }
    StrVal    : TString;     { contenu chaine (pour DK_STR)            }
    ElemCount : Integer;     { nombre d elements (pour DK_ARRAY)       }
    ElemSize  : Integer;     { taille d un element (pour DK_ARRAY)     }
  End;

  { Taille connue d un type Turbo Pascal }
  TTPSizeInfo = Record
    Name : TString;         { nom du type (Integer, Char, etc.)        }
    Size : Integer;         { taille en octets                          }
  End;

Var
  { Pool de donnees (segment .DATA) }
  DataTab    : Array[0..MAX_DATA - 1] Of TDataRec;
  DataCount  : Integer;

  { Compteur de labels auto-generes }
  LabelGenSeq : Integer;

  { Pool de tokens (pour le parseur futur) }
  TokenPool  : Array[0..MAX_TOKENS - 1] Of TToken;
  TokenCount : Integer;

{ ============================================================ }
{ TODO 05 - TABLE DES SYMBOLES                    [IMPLEMENTE] }
{ ============================================================ }

Const
  MAX_SYM   = {$IFDEF FPC}2048{$ELSE}100{$ENDIF};
  MAX_SCOPE = 64;   { profondeur max de scopes imbriques          }

  { Prefixes de mangling supplementaires pour les symboles }
  TP_FUNC_PFX = '_TPF_';   { fonctions / procedures               }
  TP_FLD_PFX  = '_TPFL_';  { champs de record                     }

Type
  { Categories de symboles dans la table }
  TSymKind = (
    SK_CONST,       { constante nommee (Const x = 42)              }
    SK_TYPE,        { type defini (Type T = ...)                    }
    SK_VAR,         { variable locale ou globale                    }
    SK_PARAM,       { parametre de procedure/fonction (valeur)      }
    SK_VARPARAM,    { parametre VAR (par reference)                 }
    SK_PROC,        { procedure                                     }
    SK_FUNC,        { fonction                                      }
    SK_FIELD,       { champ de record/objet                        }
    SK_METHOD,      { methode d objet (TP 5.5+)                    }
    SK_UNIT,        { unite importee (Uses)                         }
    SK_LABEL,       { label (Label / Goto)                          }
    SK_PROPERTY     { propriete d objet (TP8+, stub futur)         }
  );

  { Un enregistrement de la table des symboles }
  TSymRec = Record
    Name        : TString;     { nom original (majuscules)              }
    MangledName : TString;     { nom mangled pour emission ASM          }
    Kind        : TSymKind;    { categorie du symbole                   }
    TypeIdx     : Integer;     { index du type dans TypeTab (-1=aucun)  }
    Offset      : Integer;     { offset stack ou data segment           }
    ScopeLevel  : Integer;     { niveau de scope (0 = global)           }
    ScopeId     : Integer;     { id unique du scope                     }
    IsGlobal    : Boolean;     { visible globalement ?                  }
    IsExternal  : Boolean;     { declare dans une unite externe ?       }
    UnitName    : TString;     { nom de l unite d origine (ou '')       }
    ImmVal      : LongInt;     { valeur immediate (const, enum)         }
    ParamCount  : Integer;     { nombre de parametres (proc/func)       }
  End;

Var
  { Table des symboles }
  SymTab      : Array[0..MAX_SYM - 1] Of TSymRec;
  SymCount    : Integer;

  { Gestion des portees }
  CurScopeLevel : Integer;   { niveau de scope courant (0 = global)    }
  CurScopeId    : Integer;   { id du scope courant                     }
  ScopeIdSeq    : Integer;   { sequence pour generer des ids uniques    }

{ Forward declarations TODO 05 }
Procedure SymRegisterBuiltins; Forward;

{ ============================================================ }
{ TODO 06 - SYSTEME DE TYPES                      [IMPLEMENTE] }
{ ============================================================ }

Const
  MAX_TYPE   = {$IFDEF FPC}512{$ELSE}64{$ENDIF};
  MAX_FIELDS = 64;    { nombre max de champs dans un record/objet  }
  MAX_ENUMS  = 256;   { nombre max de valeurs enum                 }

  { Index des types primitifs (fixes dans TypeTab) }
  TY_UNKNOWN     = -1;  { type inconnu / pas encore defini           }
  TY_IDX_INTEGER =  0;  { Integer  (LongInt 32 bits signe)           }
  TY_IDX_WORD    =  1;  { Word     (32 bits non signe en Win32)      }
  TY_IDX_BYTE    =  2;  { Byte     (8 bits non signe)                }
  TY_IDX_SHORTINT=  3;  { ShortInt (8 bits signe)                    }
  TY_IDX_CHAR    =  4;  { Char     (8 bits)                          }
  TY_IDX_BOOLEAN =  5;  { Boolean  (8 bits, 0 ou 1)                  }
  TY_IDX_STRING  =  6;  { String   (ShortString: 1+255 octets)       }
  TY_IDX_REAL    =  7;  { Real     (stub entier 32 bits)             }
  TY_IDX_SINGLE  =  8;  { Single   (flottant 32 bits)                }
  TY_IDX_DOUBLE  =  9;  { Double   (flottant 64 bits)                }
  TY_IDX_EXTENDED= 10;  { Extended (flottant 80 bits)                }
  TY_IDX_COMP    = 11;  { Comp     (entier 64 bits virgule fixe)     }
  TY_IDX_POINTER = 12;  { Pointer  (pointeur generique 32 bits)      }
  TY_IDX_PCHAR   = 13;  { PChar    (pointeur vers Char)              }
  TY_IDX_TEXT    = 14;  { Text     (handle fichier texte)            }
  TY_IDX_NIL     = 15;  { nil      (constante pointeur nul)          }
  TY_IDX_LONGINT = 16;  { LongInt  (alias de Integer en Win32)       }
  TY_IDX_LONGWORD= 17;  { LongWord (TP8+, 32 bits non signe)        }
  TY_PRIM_COUNT  = 18;  { nombre de types primitifs                  }

Type
  { Categories de types dans la table }
  TTypeKind = (
    TYK_INTEGER,    { entier signe 32 bits (Integer, LongInt)        }
    TYK_WORD,       { entier non signe 32 bits (Word)                }
    TYK_BYTE,       { entier non signe 8 bits (Byte)                 }
    TYK_SHORTINT,   { entier signe 8 bits (ShortInt)                 }
    TYK_CHAR,       { caractere 8 bits (Char)                        }
    TYK_BOOLEAN,    { booleen 8 bits (Boolean)                       }
    TYK_STRING,     { chaine courte ShortString (String[n])          }
    TYK_REAL,       { reel (stub entier en Win32)                    }
    TYK_SINGLE,     { flottant IEEE 32 bits                          }
    TYK_DOUBLE,     { flottant IEEE 64 bits                          }
    TYK_EXTENDED,   { flottant etendu 80 bits                        }
    TYK_COMP,       { entier 64 bits virgule fixe                    }
    TYK_POINTER,    { pointeur generique 32 bits                     }
    TYK_PCHAR,      { pointeur vers Char (PChar)                     }
    TYK_ARRAY,      { tableau (ARRAY [lo..hi] OF T)                  }
    TYK_RECORD,     { record (RECORD ... END)                        }
    TYK_SET,        { ensemble (SET OF T)                            }
    TYK_ENUM,       { enumeration (TYPE T = (a, b, c))               }
    TYK_FILE,       { fichier (File / File of T)                     }
    TYK_TEXT,       { fichier texte (Text)                           }
    TYK_OBJECT,     { objet TP 5.5+ (OBJECT ... END)                }
    TYK_NIL,        { constante nil                                   }
    TYK_SUBRANGE,   { sous-intervalle (lo..hi)                       }
    TYK_PROCVAR     { variable de type procedure/fonction            }
  );

  { Un champ de record ou d objet }
  TFieldRec = Record
    Name    : TString;     { nom du champ                              }
    TypeIdx : Integer;     { index du type dans TypeTab                }
    Offset  : Integer;     { offset en octets depuis le debut du record}
  End;

  { Un enregistrement de la table des types }
  TTypeRec = Record
    Kind        : TTypeKind;   { categorie du type                     }
    Name        : TString;     { nom du type ('' si anonyme)           }
    Size        : Integer;     { taille en octets                      }
    Align       : Integer;     { alignement en octets                  }
    BaseTypeIdx : Integer;     { type de base (pointeur, tableau, alias)}
    Lo          : LongInt;     { borne inferieure (subrange, array)    }
    Hi          : LongInt;     { borne superieure (subrange, array)    }
    FieldCount  : Integer;     { nombre de champs (record, objet)      }
    Fields      : Array[0..MAX_FIELDS - 1] Of TFieldRec;
    EnumCount   : Integer;     { nombre de valeurs (enum)              }
    IsPacked    : Boolean;     { type PACKED ?                         }
    IsUnsigned  : Boolean;     { type non signe ?                      }
  End;

Var
  { Table des types }
  TypeTab   : Array[0..MAX_TYPE - 1] Of TTypeRec;
  TypeCount : Integer;

{ Forward declarations TODO 06 }
Procedure TypeInit; Forward;
Function  TypeSizeofIdx(Idx : Integer) : Integer; Forward;
Function  TypeFindByName(Const AName : TString) : Integer; Forward;
Function  TypeResolve(Idx : Integer) : Integer; Forward;
Function  TypeIsOrdinal(Idx : Integer) : Boolean; Forward;
Function  TypeIsNumeric(Idx : Integer) : Boolean; Forward;
Function  TypeIsPointer(Idx : Integer) : Boolean; Forward;
Function  TypeCoerce(IdxA, IdxB : Integer) : Integer; Forward;
Function  TypeCompatible(IdxDest, IdxSrc : Integer) : Boolean; Forward;

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

Function HexVal(Ch : Char) : Integer;
Begin
  If (Ch >= '0') And (Ch <= '9') Then
    HexVal := Ord(Ch) - Ord('0')
  Else If (Ch >= 'A') And (Ch <= 'F') Then
    HexVal := Ord(Ch) - Ord('A') + 10
  Else
    HexVal := Ord(Ch) - Ord('a') + 10;
End;

{ ------------------------------------------------------------ }
{ IsKeyword : mots-cles Turbo Pascal                           }
{ ------------------------------------------------------------ }

Function IsKeyword(Const S : TString) : Boolean;
Var
  L : TString;
  R : Boolean;
Begin
  L := StrLowerCase(S);
  R :=
    (L = 'and')         Or (L = 'array')      Or (L = 'asm')        Or
    (L = 'begin')       Or (L = 'case')       Or (L = 'const')      Or
    (L = 'div')         Or (L = 'do')         Or (L = 'downto')     Or
    (L = 'else')        Or (L = 'end')        Or (L = 'file')       Or
    (L = 'for')         Or (L = 'function')   Or (L = 'goto')       Or
    (L = 'if')          Or (L = 'implementation') Or
    (L = 'in')          Or (L = 'inline')     Or (L = 'interface')  Or
    (L = 'label')       Or (L = 'mod')        Or (L = 'nil')        Or
    (L = 'not')         Or (L = 'of')         Or (L = 'or')         Or
    (L = 'packed')      Or (L = 'procedure')  Or (L = 'program')    Or
    (L = 'record')      Or (L = 'repeat')     Or (L = 'set')        Or
    (L = 'shl')         Or (L = 'shr')        Or (L = 'string')     Or
    (L = 'then')        Or (L = 'to')         Or (L = 'type')       Or
    (L = 'unit')        Or (L = 'until')      Or (L = 'uses')       Or
    (L = 'var')         Or (L = 'while')      Or (L = 'with')       Or
    (L = 'xor');
  { Mots-cles supplementaires TP5.5+ }
  If (Not R) And TPVersionAtLeast(TP_VER_55) Then
    R :=
      (L = 'inherited')   Or (L = 'constructor') Or
      (L = 'destructor')  Or (L = 'object');
  IsKeyword := R;
End;

{ ------------------------------------------------------------ }
{ PrintToken : affichage debug de chaque token                 }
{ ------------------------------------------------------------ }

Procedure PrintToken(Const T : TToken);
Begin
  If Not Opts.DebugMode Then Exit;
  Write('  [', T.Line, ',', T.Col, '] ');
  Case T.Kind Of
    TK_EOF     : Write('EOF');
    TK_INTEGER : Write('INT(', T.IntVal, ')');
    TK_REAL    : Write('REAL(', T.Val, ')');
    TK_STRING  : Write('STR(''', T.Val, ''')');
    TK_CHAR    : Write('CHAR(#', T.IntVal, ')');
    TK_IDENT   : Write('IDENT(', T.Val, ')');
    TK_KEYWORD : Write('KW(', T.Val, ')');
    TK_OP      : Write('OP(', T.Val, ')');
    TK_PUNCT   : Write('PUNCT(', T.Val, ')');
  End;
  WriteLn;
End;

{ ------------------------------------------------------------ }
{ LexInit, LexClose, LexNextLine                               }
{ ------------------------------------------------------------ }

Procedure LexNextLine;
Begin
  If LexEOF Then Exit;
  If EOF(LexSrcF) Then
  Begin
    { Si on est dans un fichier inclus, depiler }
    If IncTop >= 0 Then
    Begin
      IncludePop;
      Exit;
    End;
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
  LexLineNo := 0;
  LexColNo  := 1;
  LexEOF    := False;
  LexLine   := '';
  CurToken.Kind    := TK_EOF;
  CurToken.Val     := '';
  CurToken.IntVal  := 0;
  CurToken.RealVal := 0.0;
  CurToken.Line    := 0;
  CurToken.Col     := 0;
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
{ Commentaires                                                 }
{ ------------------------------------------------------------ }

{ Sauter commentaire // jusqu a fin de ligne (TP7+) }
Procedure LexSkipLineComment;
Begin
  LexColNo := Length(LexLine) + 1;
End;

{ Sauter commentaire accolade ou traiter directive {$ }
Procedure LexSkipBraceComment;
Begin
  { Detecter {$ : directive de compilation }
  If (LexColNo < Length(LexLine)) And
     (LexLine[LexColNo + 1] = '$') Then
  Begin
    LexHandleDollarDirective;
    Exit;
  End;
  Inc(LexColNo); { sauter accolade ouvrante }
  While Not LexEOF Do
  Begin
    If LexColNo > Length(LexLine) Then
      LexNextLine
    Else If LexLine[LexColNo] = '}' Then
    Begin
      Inc(LexColNo);
      Exit;
    End
    Else
      Inc(LexColNo);
  End;
End;

{ Sauter commentaire (* ... *) }
Procedure LexSkipParenStarComment;
Begin
  Inc(LexColNo); Inc(LexColNo); { sauter '(' et '*' }
  While Not LexEOF Do
  Begin
    If LexColNo > Length(LexLine) Then
      LexNextLine
    Else If (LexLine[LexColNo] = '*') And
            (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = ')') Then
    Begin
      Inc(LexColNo); Inc(LexColNo);
      Exit;
    End
    Else
      Inc(LexColNo);
  End;
End;

{ ------------------------------------------------------------ }
{ LexScanIdent : identificateur ou mot-cle                     }
{ ------------------------------------------------------------ }

Procedure LexScanIdent;
Var
  S : TString;
Begin
  S := '';
  While (LexColNo <= Length(LexLine)) And IsIdentCont(LexLine[LexColNo]) Do
  Begin
    If Length(S) < MAX_STR Then
      S := S + LexLine[LexColNo];
    Inc(LexColNo);
  End;
  CurToken.Val     := S;
  CurToken.IntVal  := 0;
  CurToken.RealVal := 0.0;
  { Mots-cles Pascal : stocker en minuscules normalisees }
  If IsKeyword(S) Then
  Begin
    CurToken.Kind := TK_KEYWORD;
    CurToken.Val  := StrLowerCase(S);
  End
  Else
    CurToken.Kind := TK_IDENT;
End;

{ ------------------------------------------------------------ }
{ LexScanNumber : entier decimal ou reel                       }
{ Gere decimaux, reels (3.14, 1.5E3), token '..' vs '.'       }
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
Begin
  N       := 0;
  IsReal  := False;
  NegExp  := False;
  FracVal := 0.0;
  FracDiv := 10.0;
  ExpVal  := 0;

  { Partie entiere decimale }
  While (LexColNo <= Length(LexLine)) And
        (LexLine[LexColNo] >= '0') And (LexLine[LexColNo] <= '9') Do
  Begin
    N := N * 10 + (Ord(LexLine[LexColNo]) - Ord('0'));
    Inc(LexColNo);
  End;

  { Partie decimale .ddd (mais pas '..' qui est le token de plage) }
  If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '.') And
     (LexColNo < Length(LexLine)) And (LexLine[LexColNo + 1] <> '.') And
     (LexLine[LexColNo + 1] >= '0') And (LexLine[LexColNo + 1] <= '9') Then
  Begin
    IsReal := True;
    Inc(LexColNo); { sauter '.' }
    FracDiv := 10.0;
    FracVal := 0.0;
    While (LexColNo <= Length(LexLine)) And
          (LexLine[LexColNo] >= '0') And (LexLine[LexColNo] <= '9') Do
    Begin
      FracVal := FracVal + (Ord(LexLine[LexColNo]) - Ord('0')) / FracDiv;
      FracDiv := FracDiv * 10.0;
      Inc(LexColNo);
    End;
  End;

  { Exposant E [+-] ddd }
  If (LexColNo <= Length(LexLine)) And
     ((LexLine[LexColNo] = 'E') Or (LexLine[LexColNo] = 'e')) Then
  Begin
    IsReal := True;
    Inc(LexColNo);
    NegExp := False;
    If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '-') Then
    Begin
      NegExp := True;
      Inc(LexColNo);
    End
    Else If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '+') Then
      Inc(LexColNo);
    ExpVal := 0;
    While (LexColNo <= Length(LexLine)) And
          (LexLine[LexColNo] >= '0') And (LexLine[LexColNo] <= '9') Do
    Begin
      ExpVal := ExpVal * 10 + (Ord(LexLine[LexColNo]) - Ord('0'));
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
    CurToken.Kind    := TK_REAL;
    CurToken.RealVal := FltVal;
    If FltVal > 2147483647.0 Then N := 2147483647
    Else If FltVal < -2147483647.0 Then N := -2147483647
    Else N := Trunc(FltVal);
    CurToken.IntVal := N;
    Str(FltVal:0:6, CurToken.Val);
  End
  Else
  Begin
    CurToken.Kind    := TK_INTEGER;
    CurToken.IntVal  := N;
    CurToken.RealVal := 0.0;
    Str(N, CurToken.Val);
  End;
End;

{ ------------------------------------------------------------ }
{ LexScanHexNumber : $FF, $FFFF, $FFFFFFFF                    }
{ ------------------------------------------------------------ }

Procedure LexScanHexNumber;
Var
  N : LongInt;
Begin
  Inc(LexColNo); { sauter '$' }
  N := 0;
  While (LexColNo <= Length(LexLine)) And IsHexDigit(LexLine[LexColNo]) Do
  Begin
    N := N * 16 + HexVal(LexLine[LexColNo]);
    Inc(LexColNo);
  End;
  CurToken.Kind    := TK_INTEGER;
  CurToken.IntVal  := N;
  CurToken.RealVal := 0.0;
  Str(N, CurToken.Val);
End;

{ ------------------------------------------------------------ }
{ LexScanString : chaine Pascal entre apostrophes              }
{ Gere le doublement de quote : 'l''echo' -> l'echo            }
{ ------------------------------------------------------------ }

Procedure LexScanString;
Var
  S  : TString;
  Ch : Char;
  V  : LongInt;
Begin
  S := '';
  Inc(LexColNo); { sauter quote ouvrante }
  While LexColNo <= Length(LexLine) Do
  Begin
    Ch := LexLine[LexColNo];
    If Ch = '''' Then
    Begin
      Inc(LexColNo);
      { Quote doublee '' -> un seul caractere ' }
      If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '''') Then
      Begin
        If Length(S) < MAX_STR Then
          S := S + '''';
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

  { Concatenation implicite : 'abc'#13#10'def' }
  { Si suivi de #nn, concatener }
  While (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '#') Do
  Begin
    Inc(LexColNo); { sauter '#' }
    V := 0;
    If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '$') Then
    Begin
      Inc(LexColNo);
      While (LexColNo <= Length(LexLine)) And IsHexDigit(LexLine[LexColNo]) Do
      Begin
        V := V * 16 + HexVal(LexLine[LexColNo]);
        Inc(LexColNo);
      End;
    End
    Else
    Begin
      While (LexColNo <= Length(LexLine)) And
            (LexLine[LexColNo] >= '0') And (LexLine[LexColNo] <= '9') Do
      Begin
        V := V * 10 + (Ord(LexLine[LexColNo]) - Ord('0'));
        Inc(LexColNo);
      End;
    End;
    If Length(S) < MAX_STR Then
      S := S + Chr(V And $FF);

    { Si encore suivi d une chaine 'xxx', concatener aussi }
    If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '''') Then
    Begin
      Inc(LexColNo);
      While LexColNo <= Length(LexLine) Do
      Begin
        Ch := LexLine[LexColNo];
        If Ch = '''' Then
        Begin
          Inc(LexColNo);
          If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '''') Then
          Begin
            If Length(S) < MAX_STR Then S := S + '''';
            Inc(LexColNo);
          End
          Else
            Break;
        End
        Else
        Begin
          If Length(S) < MAX_STR Then
            S := S + Ch;
          Inc(LexColNo);
        End;
      End;
    End;
  End;

  CurToken.Kind    := TK_STRING;
  CurToken.Val     := S;
  CurToken.IntVal  := 0;
  CurToken.RealVal := 0.0;
  { Si chaine de longueur 1, stocker aussi le code ASCII }
  If Length(S) = 1 Then
    CurToken.IntVal := Ord(S[1]);
End;

{ ------------------------------------------------------------ }
{ LexScanCharLit : caractere #nn ou #$nn                       }
{ Gere aussi les sequences #13#10 et #13#10'text'              }
{ ------------------------------------------------------------ }

Procedure LexScanCharLit;
Var
  V : LongInt;
  S : TString;
  Ch : Char;
Begin
  S := '';
  { Scanner une sequence de #nn segments et concatener }
  While (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '#') Do
  Begin
    Inc(LexColNo); { sauter '#' }
    V := 0;
    If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '$') Then
    Begin
      Inc(LexColNo); { sauter '$' }
      While (LexColNo <= Length(LexLine)) And IsHexDigit(LexLine[LexColNo]) Do
      Begin
        V := V * 16 + HexVal(LexLine[LexColNo]);
        Inc(LexColNo);
      End;
    End
    Else
    Begin
      While (LexColNo <= Length(LexLine)) And
            (LexLine[LexColNo] >= '0') And (LexLine[LexColNo] <= '9') Do
      Begin
        V := V * 10 + (Ord(LexLine[LexColNo]) - Ord('0'));
        Inc(LexColNo);
      End;
    End;
    If Length(S) < MAX_STR Then
      S := S + Chr(V And $FF);
  End;

  { Si suivi d une chaine 'xxx', concatener }
  If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '''') Then
  Begin
    Inc(LexColNo); { sauter quote ouvrante }
    While LexColNo <= Length(LexLine) Do
    Begin
      Ch := LexLine[LexColNo];
      If Ch = '''' Then
      Begin
        Inc(LexColNo);
        If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '''') Then
        Begin
          If Length(S) < MAX_STR Then S := S + '''';
          Inc(LexColNo);
        End
        Else
          Break;
      End
      Else
      Begin
        If Length(S) < MAX_STR Then
          S := S + Ch;
        Inc(LexColNo);
      End;
    End;
    { Peut etre suivi d un autre #nn }
    While (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '#') Do
    Begin
      Inc(LexColNo);
      V := 0;
      If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '$') Then
      Begin
        Inc(LexColNo);
        While (LexColNo <= Length(LexLine)) And IsHexDigit(LexLine[LexColNo]) Do
        Begin
          V := V * 16 + HexVal(LexLine[LexColNo]);
          Inc(LexColNo);
        End;
      End
      Else
      Begin
        While (LexColNo <= Length(LexLine)) And
              (LexLine[LexColNo] >= '0') And (LexLine[LexColNo] <= '9') Do
        Begin
          V := V * 10 + (Ord(LexLine[LexColNo]) - Ord('0'));
          Inc(LexColNo);
        End;
      End;
      If Length(S) < MAX_STR Then
        S := S + Chr(V And $FF);
    End;
  End;

  { Si un seul caractere -> TK_CHAR, sinon TK_STRING }
  If Length(S) = 1 Then
  Begin
    CurToken.Kind   := TK_CHAR;
    CurToken.IntVal := Ord(S[1]);
  End
  Else
  Begin
    CurToken.Kind   := TK_STRING;
    CurToken.IntVal := 0;
  End;
  CurToken.Val     := S;
  CurToken.RealVal := 0.0;
End;

{ ------------------------------------------------------------ }
{ LexNextToken : produire le prochain token                    }
{ ------------------------------------------------------------ }

Procedure LexNextToken;
Var
  Ch       : Char;
  Scanning : Boolean;
Begin
  CurToken.IntVal  := 0;
  CurToken.RealVal := 0.0;

  Scanning := True;
  While Scanning Do
  Begin
    { Avancer a la prochaine ligne si fin de ligne }
    While (Not LexEOF) And (LexColNo > Length(LexLine)) Do
      LexNextLine;

    { Fin de fichier }
    If LexEOF Then
    Begin
      CurToken.Kind := TK_EOF;
      CurToken.Val  := '';
      CurToken.Line := LexLineNo;
      CurToken.Col  := LexColNo;
      Scanning := False;
      Break;
    End;

    CurToken.Line := LexLineNo;
    CurToken.Col  := LexColNo;
    Ch := LexLine[LexColNo];

    { Espaces blancs }
    If (Ch = ' ') Or (Ch = #9) Or (Ch = #13) Or (Ch = #12) Then
    Begin
      Inc(LexColNo);
    End

    { Commentaire // ligne (TP7+) }
    Else If (Ch = '/') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '/') And
            TPVersionAtLeast(TP_VER_7) Then
    Begin
      LexSkipLineComment;
    End

    { Commentaire accolade }
    Else If Ch = '{' Then
    Begin
      LexSkipBraceComment;
    End

    { Commentaire (* ... *) ou operateur '(' }
    Else If (Ch = '(') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '*') Then
    Begin
      LexSkipParenStarComment;
    End

    { Entier hexadecimal $FF }
    Else If (Ch = '$') And (LexColNo < Length(LexLine)) And
            IsHexDigit(LexLine[LexColNo + 1]) Then
    Begin
      LexScanHexNumber;
      Scanning := False;
    End

    { Caractere litteral #nn }
    Else If Ch = '#' Then
    Begin
      LexScanCharLit;
      Scanning := False;
    End

    { Chaine Pascal 'xxx' }
    Else If Ch = '''' Then
    Begin
      LexScanString;
      Scanning := False;
    End

    { Identificateur ou mot-cle }
    Else If IsIdentStart(Ch) Then
    Begin
      LexScanIdent;
      Scanning := False;
    End

    { Nombre decimal }
    Else If (Ch >= '0') And (Ch <= '9') Then
    Begin
      LexScanNumber;
      Scanning := False;
    End

    { Operateur d affectation := }
    Else If (Ch = ':') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '=') Then
    Begin
      CurToken.Kind := TK_OP;
      CurToken.Val  := ':=';
      Inc(LexColNo, 2);
      Scanning := False;
    End

    { Operateur <> }
    Else If (Ch = '<') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '>') Then
    Begin
      CurToken.Kind := TK_OP;
      CurToken.Val  := '<>';
      Inc(LexColNo, 2);
      Scanning := False;
    End

    { Operateur <= }
    Else If (Ch = '<') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '=') Then
    Begin
      CurToken.Kind := TK_OP;
      CurToken.Val  := '<=';
      Inc(LexColNo, 2);
      Scanning := False;
    End

    { Operateur >= }
    Else If (Ch = '>') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '=') Then
    Begin
      CurToken.Kind := TK_OP;
      CurToken.Val  := '>=';
      Inc(LexColNo, 2);
      Scanning := False;
    End

    { Token de plage .. }
    Else If (Ch = '.') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '.') Then
    Begin
      CurToken.Kind := TK_PUNCT;
      CurToken.Val  := '..';
      Inc(LexColNo, 2);
      Scanning := False;
    End

    { Operateurs simples }
    Else If (Ch = '+') Or (Ch = '-') Or (Ch = '*') Or (Ch = '/') Or
            (Ch = '=') Or (Ch = '<') Or (Ch = '>') Or (Ch = '@') Or
            (Ch = '^') Then
    Begin
      CurToken.Kind := TK_OP;
      CurToken.Val  := Ch;
      Inc(LexColNo);
      Scanning := False;
    End

    { Ponctuation }
    Else If (Ch = ';') Or (Ch = ',') Or (Ch = '(') Or (Ch = ')') Or
            (Ch = '[') Or (Ch = ']') Or (Ch = '.') Or (Ch = ':') Then
    Begin
      CurToken.Kind := TK_PUNCT;
      CurToken.Val  := Ch;
      Inc(LexColNo);
      Scanning := False;
    End

    { Caractere inconnu }
    Else
    Begin
      WarnMsg('caractere inattendu: ' + Ch +
              ' (ord=' + IntToStr_(Ord(Ch)) + ') ligne ' +
              IntToStr_(LexLineNo));
      Inc(LexColNo);
    End;
  End;

  PrintToken(CurToken);
End;

{ ============================================================ }
{ TODO 03 - PREPROCESSEUR ET DIRECTIVES          [IMPLEMENTE] }
{ ============================================================ }

Const
  MAX_DEFINE  = 64;    { nombre max de symboles de compilation }
  MAX_INCLUDE = 8;     { profondeur max d inclusion }

{ ---- DefineDefined : teste si un symbole est defini ---- }
Function DefineDefined(Const Name : TString) : Boolean;
Var
  I : Integer;
  N : TString;
Begin
  N := StrUpperCase(Name);
  DefineDefined := False;
  For I := 0 To DefineCount - 1 Do
    If DefineTab[I] = N Then
    Begin
      DefineDefined := True;
      Exit;
    End;
End;

{ ---- DefineAdd : ajouter un symbole de compilation ---- }
Procedure DefineAdd(Const Name : TString);
Var
  N : TString;
Begin
  N := StrUpperCase(Name);
  If DefineDefined(N) Then Exit;
  If DefineCount >= MAX_DEFINE Then
  Begin
    WarnMsg('trop de symboles $DEFINE (max ' +
            IntToStr_(MAX_DEFINE) + ')');
    Exit;
  End;
  DefineTab[DefineCount] := N;
  Inc(DefineCount);
End;

{ ---- DefineRemove : supprimer un symbole ---- }
Procedure DefineRemove(Const Name : TString);
Var
  I : Integer;
  N : TString;
Begin
  N := StrUpperCase(Name);
  For I := 0 To DefineCount - 1 Do
    If DefineTab[I] = N Then
    Begin
      DefineTab[I] := DefineTab[DefineCount - 1];
      Dec(DefineCount);
      Exit;
    End;
End;

{ ---- IncludePush : empiler le fichier courant et ouvrir un include ---- }
Procedure IncludePush(Const FileName : TString);
Var
  FullPath : TString;
  SrcDir   : TString;
Begin
  If IncTop >= MAX_INCLUDE - 1 Then
  Begin
    WarnMsg('profondeur d''inclusion maximale atteinte');
    Exit;
  End;
  { Sauvegarder l etat du lexeur }
  Inc(IncTop);
  IncSavedFName[IncTop]  := LexSrcFName;
  IncSavedLine[IncTop]   := LexLine;
  IncSavedLineNo[IncTop] := LexLineNo;
  IncSavedColNo[IncTop]  := LexColNo;
  IncSavedEOF[IncTop]    := LexEOF;
  { Fermer le fichier courant }
  Close(LexSrcF);
  { Tenter d ouvrir le fichier inclus (chemin direct) }
  FullPath := FileName;
  {$I-}
  Assign(LexSrcF, FullPath);
  Reset(LexSrcF);
  {$I+}
  If IOResult <> 0 Then
  Begin
    { Tenter dans le repertoire du fichier source }
    SrcDir := ExtractDir(LexSrcFName);
    If Length(SrcDir) > 0 Then
    Begin
      FullPath := SrcDir + FileName;
      {$I-}
      Assign(LexSrcF, FullPath);
      Reset(LexSrcF);
      {$I+}
    End;
    If IOResult <> 0 Then
    Begin
      WarnMsg('impossible d''ouvrir le fichier include: ' + FileName);
      { Rouvrir le fichier precedent }
      Assign(LexSrcF, IncSavedFName[IncTop]);
      Reset(LexSrcF);
      Dec(IncTop);
      Exit;
    End;
  End;
  LexSrcFName := FullPath;
  LexOpened := True;
  LexLine   := '';
  LexLineNo := 0;
  LexColNo  := 1;
  LexEOF    := False;
  LexNextLine;
End;

{ ---- IncludePop : depiler et restaurer le fichier precedent ---- }
Procedure IncludePop;
Var
  I : Integer;
  Dummy : TString;
Begin
  If IncTop < 0 Then Exit;
  Close(LexSrcF);
  { Rouvrir le fichier precedent et avancer jusqu a la bonne ligne }
  Assign(LexSrcF, IncSavedFName[IncTop]);
  Reset(LexSrcF);
  For I := 1 To IncSavedLineNo[IncTop] Do
  Begin
    If Not EOF(LexSrcF) Then
      ReadLn(LexSrcF, Dummy);
  End;
  LexSrcFName := IncSavedFName[IncTop];
  LexLine     := IncSavedLine[IncTop];
  LexLineNo   := IncSavedLineNo[IncTop];
  LexColNo    := IncSavedColNo[IncTop];
  LexEOF      := IncSavedEOF[IncTop];
  Dec(IncTop);
End;

{ ---- LexSkipCondFalse : sauter le code dans un IFDEF faux ---- }
{ Saute jusqu a trouver $ELSE ou $ENDIF au meme niveau }
Procedure LexSkipCondFalse;
Var
  Depth : Integer;
  P     : Integer;
  Dir   : TString;
Begin
  Depth := 1;
  While (Depth > 0) And (Not LexEOF) Do
  Begin
    If LexColNo > Length(LexLine) Then
    Begin
      LexNextLine;
      Continue;
    End;
    If LexLine[LexColNo] = '{' Then
    Begin
      P := LexColNo + 1;
      If (P <= Length(LexLine)) And (LexLine[P] = '$') Then
      Begin
        Inc(P);
        Dir := '';
        While (P <= Length(LexLine)) And (LexLine[P] <> '}') And
              (LexLine[P] <> ' ') Do
        Begin
          Dir := Dir + UpCase(LexLine[P]);
          Inc(P);
        End;
        If (Dir = 'IFDEF') Or (Dir = 'IFNDEF') Or (Dir = 'IFOPT') Then
          Inc(Depth)
        Else If Dir = 'ENDIF' Then
        Begin
          Dec(Depth);
          If Depth = 0 Then
          Begin
            { Trouver l accolade fermante }
            While (P <= Length(LexLine)) And (LexLine[P] <> '}') Do
              Inc(P);
            LexColNo := P + 1;
            Exit;
          End;
        End
        Else If (Dir = 'ELSE') And (Depth = 1) Then
        Begin
          { $ELSE au meme niveau : reprendre la compilation }
          While (P <= Length(LexLine)) And (LexLine[P] <> '}') Do
            Inc(P);
          LexColNo := P + 1;
          Exit;
        End;
      End;
      { Sauter toute l accolade }
      While (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] <> '}') Do
        Inc(LexColNo);
      If LexColNo <= Length(LexLine) Then
        Inc(LexColNo);
    End
    Else
      Inc(LexColNo);
  End;
End;

(* ---- LexHandleDollarDirective : traiter dollar-directives *)
(* Appelee quand LexColNo pointe sur accolade et le suivant est dollar *)
(* Gere: I/INCLUDE, DEFINE, UNDEF, IFDEF, IFNDEF, IFOPT, *)
(* ELSE, ENDIF, et les commutations I+/I-/R+/R-/etc. *)
Procedure LexHandleDollarDirective;
Var
  Dir  : TString;
  Arg  : TString;
  Sw   : Char;
Begin
  Inc(LexColNo);  { sauter accolade ouvrante }
  Inc(LexColNo);  { sauter $ }
  { Lire le nom de la directive }
  Dir := '';
  While (LexColNo <= Length(LexLine)) And
        IsIdentCont(LexLine[LexColNo]) Do
  Begin
    Dir := Dir + UpCase(LexLine[LexColNo]);
    Inc(LexColNo);
  End;

  (* Detecter commutateurs une lettre : dollar I+ / dollar R- etc. *)
  (* Si Dir est une seule lettre et le char courant est +/- *)
  If (Length(Dir) = 1) And (LexColNo <= Length(LexLine)) And
     ((LexLine[LexColNo] = '+') Or (LexLine[LexColNo] = '-')) Then
  Begin
    Sw := LexLine[LexColNo];
    Inc(LexColNo);
    { Consommer jusqu a accolade fermante }
    While (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] <> '}') Do
      Inc(LexColNo);
    If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '}') Then
      Inc(LexColNo);
    { Appliquer la commutation }
    Case Dir[1] Of
      'I' : OptIO          := (Sw = '+');
      'R' : OptRange       := (Sw = '+');
      'B' : OptBoolEval    := (Sw = '+');
      'Q' : OptOverflow    := (Sw = '+');
      'A' : OptAlign       := (Sw = '+');
      'N' : OptNCoprocessor:= (Sw = '+');
      'G' : OptGen286      := (Sw = '+');
      'X' : OptExtSyntax   := (Sw = '+');
    End;
    Exit;
  End;

  { Sauter espaces }
  While (LexColNo <= Length(LexLine)) And
        (LexLine[LexColNo] = ' ') Do
    Inc(LexColNo);
  { Lire l argument jusqu a accolade fermante }
  Arg := '';
  While (LexColNo <= Length(LexLine)) And
        (LexLine[LexColNo] <> '}') Do
  Begin
    Arg := Arg + LexLine[LexColNo];
    Inc(LexColNo);
  End;
  { Supprimer espaces de fin }
  While (Length(Arg) > 0) And (Arg[Length(Arg)] = ' ') Do
    Delete(Arg, Length(Arg), 1);
  { Consommer accolade fermante }
  If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '}') Then
    Inc(LexColNo);

  { Dispatcher les directives }
  If (Dir = 'I') Or (Dir = 'INCLUDE') Then
  Begin
    { Supprimer quotes eventuelles }
    If (Length(Arg) >= 2) And
       ((Arg[1] = '''') Or (Arg[1] = '"')) Then
    Begin
      Delete(Arg, 1, 1);
      If (Length(Arg) > 0) And
         ((Arg[Length(Arg)] = '''') Or (Arg[Length(Arg)] = '"')) Then
        Delete(Arg, Length(Arg), 1);
    End;
    If Length(Arg) > 0 Then
      IncludePush(Arg)
    Else
      WarnMsg('nom de fichier attendu pour $INCLUDE');
  End
  Else If Dir = 'DEFINE' Then
    DefineAdd(Arg)
  Else If Dir = 'UNDEF' Then
    DefineRemove(Arg)
  Else If Dir = 'IFDEF' Then
  Begin
    If DefineDefined(Arg) Then
      { Condition vraie : on ne fait rien }
    Else
      LexSkipCondFalse;
  End
  Else If Dir = 'IFNDEF' Then
  Begin
    If Not DefineDefined(Arg) Then
      { Condition vraie : compiler }
    Else
      LexSkipCondFalse;
  End
  Else If Dir = 'IFOPT' Then
  Begin
    { $IFOPT X+ : tester l etat d une option }
    { Format Arg = 'X+' ou 'X-' }
    If Length(Arg) >= 2 Then
    Begin
      Sw := UpCase(Arg[1]);
      If Arg[2] = '+' Then
      Begin
        Case Sw Of
          'I' : If Not OptIO Then LexSkipCondFalse;
          'R' : If Not OptRange Then LexSkipCondFalse;
          'B' : If Not OptBoolEval Then LexSkipCondFalse;
          'Q' : If Not OptOverflow Then LexSkipCondFalse;
          'A' : If Not OptAlign Then LexSkipCondFalse;
          'N' : If Not OptNCoprocessor Then LexSkipCondFalse;
          'G' : If Not OptGen286 Then LexSkipCondFalse;
          'X' : If Not OptExtSyntax Then LexSkipCondFalse;
        Else
          LexSkipCondFalse;
        End;
      End
      Else
      Begin
        Case Sw Of
          'I' : If OptIO Then LexSkipCondFalse;
          'R' : If OptRange Then LexSkipCondFalse;
          'B' : If OptBoolEval Then LexSkipCondFalse;
          'Q' : If OptOverflow Then LexSkipCondFalse;
          'A' : If OptAlign Then LexSkipCondFalse;
          'N' : If OptNCoprocessor Then LexSkipCondFalse;
          'G' : If OptGen286 Then LexSkipCondFalse;
          'X' : If OptExtSyntax Then LexSkipCondFalse;
        Else
          LexSkipCondFalse;
        End;
      End;
    End
    Else
      LexSkipCondFalse;
  End
  Else If Dir = 'ELSE' Then
  Begin
    { On est dans la branche vraie, sauter jusqu a $ENDIF }
    LexSkipCondFalse;
  End
  Else If Dir = 'ENDIF' Then
  Begin
    { Fin de bloc conditionnel, rien a faire }
  End;
  { Autres directives ($L, $M, $S, etc.) : ignorees silencieusement }
End;

{ ---- PPInitDefines : initialiser symboles predefinis ---- }
Procedure PPInitDefines;
Begin
  DefineCount := 0;
  IncTop      := -1;

  { Options de commutation par defaut (TP7) }
  OptIO          := True;   { $I+ }
  OptRange       := False;  { $R- }
  OptBoolEval    := False;  { $B- court-circuit }
  OptOverflow    := False;  { $Q- }
  OptAlign       := True;   { $A+ }
  OptNCoprocessor:= False;  { $N- }
  OptGen286      := False;  { $G- }
  OptExtSyntax   := True;   { $X+ en TP7 }

  { Symbole WIN32 toujours defini dans TPCW32 }
  DefineAdd('WIN32');

  { Symboles MSDOS, CPU86, CPU87 }
  DefineAdd('MSDOS');
  DefineAdd('CPU86');
  DefineAdd('CPU87');

  { Symboles de version selon TPVersion }
  If TPVersionAtLeast(TP_VER_1) Then DefineAdd('VER10');
  If TPVersionAtLeast(TP_VER_2) Then DefineAdd('VER20');
  If TPVersionAtLeast(TP_VER_4) Then DefineAdd('VER40');
  If TPVersionAtLeast(TP_VER_5) Then DefineAdd('VER50');
  If TPVersionAtLeast(TP_VER_55) Then DefineAdd('VER55');
  If TPVersionAtLeast(TP_VER_6) Then DefineAdd('VER60');
  If TPVersionAtLeast(TP_VER_7) Then DefineAdd('VER70');
  If TPVersionAtLeast(TP_VER_8) Then DefineAdd('VER80');
End;

{ ============================================================ }
{ TODO 04 - LITTERAUX ET CONSTANTES               [IMPLEMENTE] }
{ ============================================================ }

{ ---- Table des tailles de types Turbo Pascal (Win32) ---- }
Const
  TPTypeSizes : Array[0..MAX_TP_TYPE_SIZES - 1] Of TTPSizeInfo = (
    (Name: 'INTEGER';   Size: 4),   { LongInt 32 bits en Win32          }
    (Name: 'LONGINT';   Size: 4),   { LongInt 32 bits                   }
    (Name: 'WORD';      Size: 4),   { elargi a 32 bits en Win32         }
    (Name: 'BYTE';      Size: 1),   { 8 bits non signe                  }
    (Name: 'SHORTINT';  Size: 1),   { 8 bits signe                      }
    (Name: 'CHAR';      Size: 1),   { caractere 8 bits                  }
    (Name: 'BOOLEAN';   Size: 1),   { booleen 8 bits                    }
    (Name: 'STRING';    Size: 256), { ShortString (255+1 longueur)      }
    (Name: 'REAL';      Size: 4),   { stub entier, 4 octets en Win32    }
    (Name: 'SINGLE';    Size: 4),   { flottant 32 bits                  }
    (Name: 'DOUBLE';    Size: 8),   { flottant 64 bits                  }
    (Name: 'EXTENDED';  Size: 10),  { flottant 80 bits                  }
    (Name: 'COMP';      Size: 8),   { entier 64 bits en virgule fixe    }
    (Name: 'POINTER';   Size: 4),   { pointeur generique 32 bits        }
    (Name: 'PCHAR';     Size: 4),   { pointeur vers Char                }
    (Name: 'TEXT';      Size: 4),   { handle fichier texte              }
    (Name: 'FILE';      Size: 4),   { handle fichier                    }
    (Name: 'LONGWORD';  Size: 4)    { mot 32 bits non signe (TP8)       }
  );

{ ---- DataInit : initialiser le pool de donnees ---- }
Procedure DataInit;
Var I : Integer;
Begin
  DataCount   := 0;
  LabelGenSeq := 0;
  TokenCount  := 0;
  For I := 0 To MAX_DATA - 1 Do
  Begin
    DataTab[I].LblName   := '';
    DataTab[I].Kind      := DK_STR;
    DataTab[I].IntVal    := 0;
    DataTab[I].StrVal    := '';
    DataTab[I].ElemCount := 0;
    DataTab[I].ElemSize  := 0;
  End;
End;

{ ---- DataAdd : ajouter une entree generique dans le pool ---- }
Function DataAdd(Const Lbl : TString; Kind : TDataKind;
                 AIntVal : LongInt; Const AStrVal : TString;
                 AElemCount : Integer; AElemSize : Integer) : Integer;
Begin
  If DataCount >= MAX_DATA Then
  Begin
    WarnMsg('pool de donnees plein (MAX_DATA=' + IntToStr_(MAX_DATA) + ')');
    DataAdd := -1;
    Exit;
  End;
  DataTab[DataCount].LblName   := Lbl;
  DataTab[DataCount].Kind      := Kind;
  DataTab[DataCount].IntVal    := AIntVal;
  DataTab[DataCount].StrVal    := AStrVal;
  DataTab[DataCount].ElemCount := AElemCount;
  DataTab[DataCount].ElemSize  := AElemSize;
  DataAdd := DataCount;
  Inc(DataCount);
End;

{ ---- DataAddStr : ajouter une chaine avec label auto-genere ---- }
{ Retourne le label (ex: _TPK_1) }
Function DataAddStr(Const S : TString) : TString;
Var Lbl : TString;
Begin
  Inc(LabelGenSeq);
  Lbl := TP_STR_PFX + IntToStr_(LabelGenSeq);
  DataAdd(Lbl, DK_STR, 0, S, 0, 0);
  DataAddStr := Lbl;
End;

{ ---- DataAddDWord : ajouter une valeur 32 bits avec label ---- }
Function DataAddDWord(Const Lbl : TString; Val : LongInt) : Integer;
Begin
  DataAddDWord := DataAdd(Lbl, DK_DWORD, Val, '', 0, 0);
End;

{ ---- DataAddByte : ajouter une valeur 8 bits avec label ---- }
Function DataAddByte(Const Lbl : TString; Val : Integer) : Integer;
Begin
  DataAddByte := DataAdd(Lbl, DK_BYTE, Val, '', 0, 0);
End;

{ ---- DataAddArray : ajouter un tableau avec label ---- }
Function DataAddArray(Const Lbl : TString;
                      AElemCount : Integer;
                      AElemSize : Integer) : Integer;
Begin
  DataAddArray := DataAdd(Lbl, DK_ARRAY, 0, '', AElemCount, AElemSize);
End;

{ ---- DataAddRes : ajouter un espace reserve avec label ---- }
Function DataAddRes(Const Lbl : TString; Size : Integer) : Integer;
Begin
  DataAddRes := DataAdd(Lbl, DK_RES, Size, '', 0, 0);
End;

{ ---- DataAddStruct : ajouter un record/structure ---- }
Function DataAddStruct(Const Lbl : TString; Size : Integer) : Integer;
Begin
  DataAddStruct := DataAdd(Lbl, DK_STRUCT, Size, '', 0, 0);
End;

{ ---- DataAddZero : ajouter un espace initialise a zero ---- }
Function DataAddZero(Const Lbl : TString; Size : Integer) : Integer;
Begin
  DataAddZero := DataAdd(Lbl, DK_ZERO, Size, '', 0, 0);
End;

{ ---- DataFindStr : rechercher si une chaine est deja dans le pool ---- }
{ Retourne l index ou -1 si absente }
Function DataFindStr(Const S : TString) : Integer;
Var I : Integer;
Begin
  DataFindStr := -1;
  For I := 0 To DataCount - 1 Do
    If (DataTab[I].Kind = DK_STR) And (DataTab[I].StrVal = S) Then
    Begin
      DataFindStr := I;
      Exit;
    End;
End;

{ ---- DataGetOrAddStr : retourne le label d une chaine existante ---- }
{ ou l ajoute si elle n existe pas encore (deduplication) }
Function DataGetOrAddStr(Const S : TString) : TString;
Var Idx : Integer;
Begin
  Idx := DataFindStr(S);
  If Idx >= 0 Then
    DataGetOrAddStr := DataTab[Idx].LblName
  Else
    DataGetOrAddStr := DataAddStr(S);
End;

{ ---- TPTypeSizeof : retourne la taille d un type TP de base ---- }
{ Retourne -1 si le type est inconnu }
Function TPTypeSizeof(Const TypeName : TString) : Integer;
Var
  I : Integer;
  N : TString;
Begin
  TPTypeSizeof := -1;
  N := StrUpperCase(TypeName);
  For I := 0 To MAX_TP_TYPE_SIZES - 1 Do
    If TPTypeSizes[I].Name = N Then
    Begin
      TPTypeSizeof := TPTypeSizes[I].Size;
      Exit;
    End;
  { Pointeur : tout type ^xxx a la taille d un pointeur }
  If (Length(N) > 1) And (N[1] = '^') Then
  Begin
    TPTypeSizeof := 4;  { 32 bits }
    Exit;
  End;
End;

{ ---- ConstEvalExpr : evaluer une expression constante TP ---- }
{ Supporte : entiers, hex, Ord, Chr, SizeOf, MaxInt, True, False, Nil }
{ Operateurs : + - * DIV MOD AND OR XOR NOT SHL SHR ( )  }

Function ConstEvalExpr(Const S : TString; Var Pos : Integer) : LongInt;
  Forward;

Function ConstEvalAtom(Const S : TString; Var Pos : Integer) : LongInt;
Var
  N   : LongInt;
  Neg : Boolean;
  Id  : TString;
  Sz  : Integer;
  Arg : TString;
  Depth : Integer;
Begin
  N := 0;

  { Sauter les blancs }
  While (Pos <= Length(S)) And ((S[Pos] = ' ') Or (S[Pos] = #9)) Do
    Inc(Pos);

  If Pos > Length(S) Then
  Begin
    ConstEvalAtom := 0;
    Exit;
  End;

  { Operateur unaire - }
  Neg := False;
  If (Pos <= Length(S)) And (S[Pos] = '-') Then
  Begin
    Neg := True;
    Inc(Pos);
    While (Pos <= Length(S)) And ((S[Pos] = ' ') Or (S[Pos] = #9)) Do
      Inc(Pos);
  End;

  { Operateur unaire + }
  If (Pos <= Length(S)) And (S[Pos] = '+') Then
  Begin
    Inc(Pos);
    While (Pos <= Length(S)) And ((S[Pos] = ' ') Or (S[Pos] = #9)) Do
      Inc(Pos);
  End;

  { NOT : operateur unaire TP }
  If (Pos + 2 <= Length(S)) And
     (UpCase(S[Pos]) = 'N') And (UpCase(S[Pos+1]) = 'O') And
     (UpCase(S[Pos+2]) = 'T') And
     ((Pos + 3 > Length(S)) Or Not IsIdentCont(S[Pos+3])) Then
  Begin
    Inc(Pos, 3);
    N := Not ConstEvalAtom(S, Pos);
    If Neg Then N := -N;
    ConstEvalAtom := N;
    Exit;
  End;

  { Parentheses }
  If (Pos <= Length(S)) And (S[Pos] = '(') Then
  Begin
    Inc(Pos);
    N := ConstEvalExpr(S, Pos);
    If (Pos <= Length(S)) And (S[Pos] = ')') Then
      Inc(Pos);
    If Neg Then N := -N;
    ConstEvalAtom := N;
    Exit;
  End;

  { Caractere #nn ou #$nn }
  If (Pos <= Length(S)) And (S[Pos] = '#') Then
  Begin
    Inc(Pos);
    If (Pos <= Length(S)) And (S[Pos] = '$') Then
    Begin
      { Hex char #$41 }
      Inc(Pos);
      N := 0;
      While (Pos <= Length(S)) And IsHexDigit(S[Pos]) Do
      Begin
        N := N * 16 + HexVal(S[Pos]);
        Inc(Pos);
      End;
    End
    Else
    Begin
      { Decimal char #65 }
      N := 0;
      While (Pos <= Length(S)) And IsDigit(S[Pos]) Do
      Begin
        N := N * 10 + (Ord(S[Pos]) - Ord('0'));
        Inc(Pos);
      End;
    End;
    If Neg Then N := -N;
    ConstEvalAtom := N;
    Exit;
  End;

  { Chaine un caractere 'A' -> Ord('A') }
  If (Pos <= Length(S)) And (S[Pos] = '''') Then
  Begin
    Inc(Pos);
    If Pos <= Length(S) Then
    Begin
      N := Ord(S[Pos]);
      Inc(Pos);
    End;
    If (Pos <= Length(S)) And (S[Pos] = '''') Then
      Inc(Pos);
    If Neg Then N := -N;
    ConstEvalAtom := N;
    Exit;
  End;

  { Hex $FF }
  If (Pos <= Length(S)) And (S[Pos] = '$') Then
  Begin
    Inc(Pos);
    N := 0;
    While (Pos <= Length(S)) And IsHexDigit(S[Pos]) Do
    Begin
      N := N * 16 + HexVal(S[Pos]);
      Inc(Pos);
    End;
    If Neg Then N := -N;
    ConstEvalAtom := N;
    Exit;
  End;

  { Nombre decimal }
  If (Pos <= Length(S)) And IsDigit(S[Pos]) Then
  Begin
    N := 0;
    While (Pos <= Length(S)) And IsDigit(S[Pos]) Do
    Begin
      N := N * 10 + (Ord(S[Pos]) - Ord('0'));
      Inc(Pos);
    End;
    { Ignorer la partie decimale pour les reels }
    If (Pos <= Length(S)) And (S[Pos] = '.') Then
    Begin
      Inc(Pos);
      While (Pos <= Length(S)) And IsDigit(S[Pos]) Do
        Inc(Pos);
      { Ignorer exposant }
      If (Pos <= Length(S)) And (UpCase(S[Pos]) = 'E') Then
      Begin
        Inc(Pos);
        If (Pos <= Length(S)) And ((S[Pos] = '+') Or (S[Pos] = '-')) Then
          Inc(Pos);
        While (Pos <= Length(S)) And IsDigit(S[Pos]) Do
          Inc(Pos);
      End;
    End;
    If Neg Then N := -N;
    ConstEvalAtom := N;
    Exit;
  End;

  { Identificateur : mot-cle ou constante nommee }
  If (Pos <= Length(S)) And IsIdentStart(S[Pos]) Then
  Begin
    Id := '';
    While (Pos <= Length(S)) And IsIdentCont(S[Pos]) Do
    Begin
      Id := Id + UpCase(S[Pos]);
      Inc(Pos);
    End;
    While (Pos <= Length(S)) And ((S[Pos] = ' ') Or (S[Pos] = #9)) Do
      Inc(Pos);

    { Constantes predefinies }
    If Id = 'TRUE' Then N := 1
    Else If Id = 'FALSE' Then N := 0
    Else If Id = 'NIL' Then N := 0
    Else If Id = 'MAXINT' Then N := 32767
    Else If Id = 'MAXLONGINT' Then N := 2147483647

    { Fonctions de conversion }
    Else If Id = 'ORD' Then
    Begin
      If (Pos <= Length(S)) And (S[Pos] = '(') Then
      Begin
        Inc(Pos);
        N := ConstEvalExpr(S, Pos);
        If (Pos <= Length(S)) And (S[Pos] = ')') Then
          Inc(Pos);
      End;
    End
    Else If Id = 'CHR' Then
    Begin
      If (Pos <= Length(S)) And (S[Pos] = '(') Then
      Begin
        Inc(Pos);
        N := ConstEvalExpr(S, Pos);
        N := N And $FF;
        If (Pos <= Length(S)) And (S[Pos] = ')') Then
          Inc(Pos);
      End;
    End
    Else If Id = 'SIZEOF' Then
    Begin
      If (Pos <= Length(S)) And (S[Pos] = '(') Then
      Begin
        Inc(Pos);
        { Lire le nom du type comme argument }
        While (Pos <= Length(S)) And ((S[Pos] = ' ') Or (S[Pos] = #9)) Do
          Inc(Pos);
        Arg := '';
        Depth := 1;
        While (Pos <= Length(S)) And (Depth > 0) Do
        Begin
          If S[Pos] = '(' Then Inc(Depth)
          Else If S[Pos] = ')' Then
          Begin
            Dec(Depth);
            If Depth = 0 Then
            Begin
              Inc(Pos);
              Break;
            End;
          End;
          Arg := Arg + S[Pos];
          Inc(Pos);
        End;
        { Supprimer espaces de fin }
        While (Length(Arg) > 0) And (Arg[Length(Arg)] = ' ') Do
          Delete(Arg, Length(Arg), 1);
        Sz := TPTypeSizeof(Arg);
        If Sz >= 0 Then
          N := Sz
        Else
          N := 4;  { taille par defaut pour types inconnus (32 bits) }
      End;
    End
    Else If Id = 'SUCC' Then
    Begin
      If (Pos <= Length(S)) And (S[Pos] = '(') Then
      Begin
        Inc(Pos);
        N := ConstEvalExpr(S, Pos) + 1;
        If (Pos <= Length(S)) And (S[Pos] = ')') Then
          Inc(Pos);
      End;
    End
    Else If Id = 'PRED' Then
    Begin
      If (Pos <= Length(S)) And (S[Pos] = '(') Then
      Begin
        Inc(Pos);
        N := ConstEvalExpr(S, Pos) - 1;
        If (Pos <= Length(S)) And (S[Pos] = ')') Then
          Inc(Pos);
      End;
    End
    Else If Id = 'ABS' Then
    Begin
      If (Pos <= Length(S)) And (S[Pos] = '(') Then
      Begin
        Inc(Pos);
        N := ConstEvalExpr(S, Pos);
        If N < 0 Then N := -N;
        If (Pos <= Length(S)) And (S[Pos] = ')') Then
          Inc(Pos);
      End;
    End
    Else If Id = 'LO' Then
    Begin
      If (Pos <= Length(S)) And (S[Pos] = '(') Then
      Begin
        Inc(Pos);
        N := ConstEvalExpr(S, Pos) And $FF;
        If (Pos <= Length(S)) And (S[Pos] = ')') Then
          Inc(Pos);
      End;
    End
    Else If Id = 'HI' Then
    Begin
      If (Pos <= Length(S)) And (S[Pos] = '(') Then
      Begin
        Inc(Pos);
        N := (ConstEvalExpr(S, Pos) Shr 8) And $FF;
        If (Pos <= Length(S)) And (S[Pos] = ')') Then
          Inc(Pos);
      End;
    End
    Else If Id = 'SWAP' Then
    Begin
      If (Pos <= Length(S)) And (S[Pos] = '(') Then
      Begin
        Inc(Pos);
        N := ConstEvalExpr(S, Pos);
        N := ((N And $FF) Shl 8) Or ((N Shr 8) And $FF);
        If (Pos <= Length(S)) And (S[Pos] = ')') Then
          Inc(Pos);
      End;
    End
    Else
      N := 0;  { identificateur inconnu : 0 par defaut }

    If Neg Then N := -N;
    ConstEvalAtom := N;
    Exit;
  End;

  { Par defaut }
  ConstEvalAtom := 0;
End;

{ ---- ConstEvalExpr : evaluer une expression constante entiere ---- }
{ Operateurs TP : + - * DIV MOD AND OR XOR SHL SHR = <> < > <= >= }
Function ConstEvalExpr(Const S : TString; Var Pos : Integer) : LongInt;
Var
  L, R : LongInt;
  Op   : TString;
Begin
  L := ConstEvalAtom(S, Pos);

  While Pos <= Length(S) Do
  Begin
    { Sauter blancs }
    While (Pos <= Length(S)) And ((S[Pos] = ' ') Or (S[Pos] = #9)) Do
      Inc(Pos);
    If Pos > Length(S) Then Break;

    { Detecter l operateur }
    Op := '';
    If S[Pos] = '+' Then Begin Op := '+'; Inc(Pos); End
    Else If S[Pos] = '-' Then Begin Op := '-'; Inc(Pos); End
    Else If S[Pos] = '*' Then Begin Op := '*'; Inc(Pos); End
    Else If (S[Pos] = '<') And (Pos + 1 <= Length(S)) And (S[Pos+1] = '>') Then
      Begin Op := '<>'; Inc(Pos, 2); End
    Else If (S[Pos] = '<') And (Pos + 1 <= Length(S)) And (S[Pos+1] = '=') Then
      Begin Op := '<='; Inc(Pos, 2); End
    Else If (S[Pos] = '>') And (Pos + 1 <= Length(S)) And (S[Pos+1] = '=') Then
      Begin Op := '>='; Inc(Pos, 2); End
    Else If S[Pos] = '<' Then Begin Op := '<'; Inc(Pos); End
    Else If S[Pos] = '>' Then Begin Op := '>'; Inc(Pos); End
    Else If S[Pos] = '=' Then Begin Op := '='; Inc(Pos); End
    Else If IsIdentStart(S[Pos]) Then
    Begin
      { Mots-cles operateurs : DIV, MOD, AND, OR, XOR, SHL, SHR }
      Op := '';
      While (Pos <= Length(S)) And IsIdentCont(S[Pos]) Do
      Begin
        Op := Op + UpCase(S[Pos]);
        Inc(Pos);
      End;
      If (Op <> 'DIV') And (Op <> 'MOD') And (Op <> 'AND') And
         (Op <> 'OR') And (Op <> 'XOR') And (Op <> 'SHL') And
         (Op <> 'SHR') Then
      Begin
        { Pas un operateur connu, reculer }
        Dec(Pos, Length(Op));
        Break;
      End;
    End
    Else
      Break;  { pas un operateur reconnu }

    R := ConstEvalAtom(S, Pos);

    If Op = '+' Then L := L + R
    Else If Op = '-' Then L := L - R
    Else If Op = '*' Then L := L * R
    Else If Op = 'DIV' Then
    Begin
      If R <> 0 Then L := L Div R Else L := 0;
    End
    Else If Op = 'MOD' Then
    Begin
      If R <> 0 Then L := L Mod R Else L := 0;
    End
    Else If Op = 'AND' Then L := L And R
    Else If Op = 'OR' Then L := L Or R
    Else If Op = 'XOR' Then L := L Xor R
    Else If Op = 'SHL' Then L := L Shl R
    Else If Op = 'SHR' Then L := L Shr R
    Else If Op = '=' Then Begin If L = R Then L := 1 Else L := 0; End
    Else If Op = '<>' Then Begin If L <> R Then L := 1 Else L := 0; End
    Else If Op = '<' Then Begin If L < R Then L := 1 Else L := 0; End
    Else If Op = '>' Then Begin If L > R Then L := 1 Else L := 0; End
    Else If Op = '<=' Then Begin If L <= R Then L := 1 Else L := 0; End
    Else If Op = '>=' Then Begin If L >= R Then L := 1 Else L := 0; End;
  End;

  ConstEvalExpr := L;
End;

{ ---- ConstEval : evaluer une expression constante complete ---- }
{ Encapsulation avec initialisation de Pos }
Function ConstEval(Const S : TString) : LongInt;
Var P : Integer;
Begin
  P := 1;
  ConstEval := ConstEvalExpr(S, P);
End;

{ ---- TokenPoolInit : initialiser le pool de tokens ---- }
Procedure TokenPoolInit;
Begin
  TokenCount := 0;
End;

{ ---- TokenPoolAdd : ajouter un token dans le pool ---- }
Procedure TokenPoolAdd(Const T : TToken);
Begin
  If TokenCount >= MAX_TOKENS Then
  Begin
    WarnMsg('pool de tokens plein');
    Exit;
  End;
  TokenPool[TokenCount] := T;
  Inc(TokenCount);
End;

{ ---- TokenPoolRegisterStrings : enregistrer toutes les chaines ---- }
{ du pool de tokens dans le pool de donnees, en evitant les doublons }
Procedure TokenPoolRegisterStrings;
Var I : Integer;
Begin
  For I := 0 To TokenCount - 1 Do
  Begin
    If TokenPool[I].Kind = TK_STRING Then
      DataGetOrAddStr(TokenPool[I].Val);
  End;
End;

{ ============================================================ }
{ TODO 05 - TABLE DES SYMBOLES                    [IMPLEMENTE] }
{ ============================================================ }

{ ------------------------------------------------------------ }
{ SymInit : initialiser la table des symboles                  }
{ ------------------------------------------------------------ }

Procedure SymInit;
Var I : Integer;
Begin
  SymCount      := 0;
  CurScopeLevel := 0;
  CurScopeId    := 0;
  ScopeIdSeq    := 0;
  For I := 0 To MAX_SYM - 1 Do
  Begin
    SymTab[I].Name        := '';
    SymTab[I].MangledName := '';
    SymTab[I].Kind        := SK_VAR;
    SymTab[I].TypeIdx     := -1;
    SymTab[I].Offset      := 0;
    SymTab[I].ScopeLevel  := 0;
    SymTab[I].ScopeId     := 0;
    SymTab[I].IsGlobal    := False;
    SymTab[I].IsExternal  := False;
    SymTab[I].UnitName    := '';
    SymTab[I].ImmVal      := 0;
    SymTab[I].ParamCount  := 0;
  End;
  SymRegisterBuiltins;
End;

{ ------------------------------------------------------------ }
{ SymMangle : generer un nom mangled pour un symbole           }
{ selon sa categorie                                           }
{ ------------------------------------------------------------ }

Function SymMangle(Const Name : TString; Kind : TSymKind) : TString;
Begin
  Case Kind Of
    SK_CONST    : SymMangle := TP_VAR_PFX + Name;
    SK_TYPE     : SymMangle := Name;
    SK_VAR      : SymMangle := TP_VAR_PFX + Name;
    SK_PARAM    : SymMangle := TP_VAR_PFX + Name;
    SK_PROC     : SymMangle := TP_FUNC_PFX + Name;
    SK_FUNC     : SymMangle := TP_FUNC_PFX + Name;
    SK_FIELD    : SymMangle := TP_FLD_PFX + Name;
    SK_METHOD   : SymMangle := TP_FUNC_PFX + Name;
    SK_UNIT     : SymMangle := Name;
    SK_LABEL    : SymMangle := TP_LBL_PFX + Name;
    SK_PROPERTY : SymMangle := Name;
  Else
    SymMangle := TP_VAR_PFX + Name;
  End;
End;

{ ------------------------------------------------------------ }
{ SymFindInScope : chercher un symbole dans un scope precis    }
{ Retourne l index ou -1 si non trouve                         }
{ Comparaison insensible a la casse (Turbo Pascal)             }
{ ------------------------------------------------------------ }

Function SymFindInScope(Const Name : TString;
                        Level : Integer) : Integer;
Var
  I  : Integer;
  Up : TString;
Begin
  Up := StrUpperCase(Name);
  For I := SymCount - 1 DownTo 0 Do
  Begin
    If (SymTab[I].Name = Up) And
       (SymTab[I].ScopeLevel = Level) And
       ((Level = 0) Or (SymTab[I].ScopeId = CurScopeId)) Then
    Begin
      SymFindInScope := I;
      Exit;
    End;
  End;
  SymFindInScope := -1;
End;

{ ------------------------------------------------------------ }
{ SymFind : chercher un symbole du scope courant vers global   }
{ Retourne l index ou -1 si non trouve                         }
{ ------------------------------------------------------------ }

Function SymFind(Const Name : TString) : Integer;
Var
  I  : Integer;
  Up : TString;
Begin
  Up := StrUpperCase(Name);
  For I := SymCount - 1 DownTo 0 Do
  Begin
    If (SymTab[I].Name = Up) And
       (SymTab[I].ScopeLevel <= CurScopeLevel) Then
    Begin
      SymFind := I;
      Exit;
    End;
  End;
  SymFind := -1;
End;

{ ------------------------------------------------------------ }
{ SymFindInUnit : chercher un symbole qualifie par unite        }
{ Ex: Crt.ClrScr -> chercher ClrScr avec UnitName='CRT'       }
{ ------------------------------------------------------------ }

Function SymFindInUnit(Const UName, Name : TString) : Integer;
Var
  I  : Integer;
  Up : TString;
  UU : TString;
Begin
  Up := StrUpperCase(Name);
  UU := StrUpperCase(UName);
  For I := SymCount - 1 DownTo 0 Do
  Begin
    If (SymTab[I].Name = Up) And
       (SymTab[I].UnitName = UU) Then
    Begin
      SymFindInUnit := I;
      Exit;
    End;
  End;
  SymFindInUnit := -1;
End;

{ ------------------------------------------------------------ }
{ SymAdd : ajouter un symbole dans la table                    }
{ Retourne l index du symbole ajoute, ou -1 si erreur          }
{ ------------------------------------------------------------ }

Function SymAdd(Const Name : TString; Kind : TSymKind;
                TIdx : Integer) : Integer;
Var
  Up  : TString;
  Dup : Integer;
Begin
  If SymCount >= MAX_SYM Then
  Begin
    WarnMsg('table des symboles pleine (MAX_SYM=' +
      IntToStr_(MAX_SYM) + ')');
    SymAdd := -1;
    Exit;
  End;

  Up := StrUpperCase(Name);

  { Verifier doublon dans le scope courant }
  Dup := SymFindInScope(Up, CurScopeLevel);
  If Dup >= 0 Then
  Begin
    { Permettre la redefinition d une forward declaration }
    If SymTab[Dup].IsExternal And
       (Kind In [SK_PROC, SK_FUNC, SK_VAR]) Then
    Begin
      SymTab[Dup].Kind       := Kind;
      SymTab[Dup].TypeIdx    := TIdx;
      SymTab[Dup].IsExternal := False;
      SymAdd := Dup;
      Exit;
    End
    { Permettre qu un proc/func masque un type pre-declare }
    Else If (SymTab[Dup].Kind = SK_TYPE) And
            (Kind In [SK_PROC, SK_FUNC, SK_VAR]) Then
    Begin
      { On laisse passer, le nouveau symbole sera ajoute }
    End
    Else
    Begin
      WarnMsg('symbole deja defini dans ce scope: ' + Up);
      SymAdd := Dup;
      Exit;
    End;
  End;

  { Ajouter le symbole }
  SymTab[SymCount].Name        := Up;
  SymTab[SymCount].MangledName := SymMangle(Up, Kind);
  SymTab[SymCount].Kind        := Kind;
  SymTab[SymCount].TypeIdx     := TIdx;
  SymTab[SymCount].Offset      := 0;
  SymTab[SymCount].ScopeLevel  := CurScopeLevel;
  SymTab[SymCount].ScopeId     := CurScopeId;
  SymTab[SymCount].IsGlobal    := (CurScopeLevel = 0);
  SymTab[SymCount].IsExternal  := False;
  SymTab[SymCount].UnitName    := '';
  SymTab[SymCount].ImmVal      := 0;
  SymTab[SymCount].ParamCount  := 0;

  SymAdd := SymCount;
  Inc(SymCount);
End;

{ ------------------------------------------------------------ }
{ SymEnterScope / SymLeaveScope : gestion des portees           }
{ ------------------------------------------------------------ }

Procedure SymEnterScope;
Begin
  If CurScopeLevel >= MAX_SCOPE Then
  Begin
    WarnMsg('profondeur de scope maximale atteinte');
    Exit;
  End;
  Inc(CurScopeLevel);
  Inc(ScopeIdSeq);
  CurScopeId := ScopeIdSeq;
  If Opts.DebugMode Then
    WriteLn('  SCOPE_ENTER: level=', CurScopeLevel,
            ' id=', CurScopeId);
End;

Procedure SymLeaveScope;
Begin
  If CurScopeLevel <= 0 Then
  Begin
    WarnMsg('tentative de quitter le scope global');
    Exit;
  End;
  If Opts.DebugMode Then
    WriteLn('  SCOPE_LEAVE: level=', CurScopeLevel);
  Dec(CurScopeLevel);
  If CurScopeLevel = 0 Then
    CurScopeId := 0
  Else
    CurScopeId := CurScopeLevel;
End;

{ ------------------------------------------------------------ }
{ SymRegisterBuiltins : pre-enregistrer les types, constantes, }
{ procedures et fonctions predefinies de Turbo Pascal           }
{ Le compilateur les reconnait automatiquement sans qu ils      }
{ soient declares explicitement dans le code source.            }
{ ------------------------------------------------------------ }

Procedure SymRegisterBuiltins;

  { Registrer un type predefini }
  Procedure RegType(Const Name : TString);
  Var R, TIdx : Integer;
  Begin
    TIdx := TypeFindByName(Name);
    R := SymAdd(Name, SK_TYPE, TIdx);
    If R >= 0 Then
      SymTab[R].IsGlobal := True;
  End;

  { Registrer une constante predefinie avec valeur }
  Procedure RegConst(Const Name : TString; Val : LongInt);
  Var R : Integer;
  Begin
    R := SymAdd(Name, SK_CONST, -1);
    If R >= 0 Then
    Begin
      SymTab[R].ImmVal   := Val;
      SymTab[R].IsGlobal := True;
    End;
  End;

  { Registrer une procedure predefinie }
  Procedure RegProc(Const Name : TString);
  Var R : Integer;
  Begin
    R := SymAdd(Name, SK_PROC, -1);
    If R >= 0 Then
    Begin
      SymTab[R].IsGlobal  := True;
      SymTab[R].IsExternal := True;
    End;
  End;

  { Registrer une fonction predefinie }
  Procedure RegFunc(Const Name : TString);
  Var R : Integer;
  Begin
    R := SymAdd(Name, SK_FUNC, -1);
    If R >= 0 Then
    Begin
      SymTab[R].IsGlobal  := True;
      SymTab[R].IsExternal := True;
    End;
  End;

Begin
  { ---------------------------------------------------------- }
  { Types predefinis Turbo Pascal                              }
  { ---------------------------------------------------------- }
  RegType('INTEGER');    RegType('LONGINT');
  RegType('WORD');       RegType('BYTE');
  RegType('SHORTINT');   RegType('CHAR');
  RegType('BOOLEAN');    RegType('STRING');
  RegType('REAL');       RegType('POINTER');
  RegType('TEXT');       RegType('PCHAR');

  { Types TP 5+ }
  If TPVersionAtLeast(TP_VER_5) Then
  Begin
    RegType('SINGLE');   RegType('DOUBLE');
    RegType('EXTENDED'); RegType('COMP');
  End;

  { Types TP 7+ }
  If TPVersionAtLeast(TP_VER_7) Then
  Begin
    RegType('LONGWORD');
  End;

  { ---------------------------------------------------------- }
  { Constantes predefinies                                      }
  { ---------------------------------------------------------- }
  RegConst('TRUE', 1);
  RegConst('FALSE', 0);
  RegConst('NIL', 0);
  RegConst('MAXINT', 32767);
  RegConst('MAXLONGINT', 2147483647);

  { ---------------------------------------------------------- }
  { Procedures et fonctions predefinies (toujours disponibles) }
  { ---------------------------------------------------------- }

  { E/S standard }
  RegProc('WRITE');      RegProc('WRITELN');
  RegProc('READ');       RegProc('READLN');

  { Conversion chaines }
  RegProc('STR');        RegProc('VAL');

  { Allocation memoire }
  RegProc('NEW');        RegProc('DISPOSE');
  RegProc('GETMEM');     RegProc('FREEMEM');

  { Inc / Dec }
  RegProc('INC');        RegProc('DEC');

  { Fonctions ordinales }
  RegFunc('ORD');        RegFunc('CHR');
  RegFunc('SUCC');       RegFunc('PRED');
  RegFunc('LOW');        RegFunc('HIGH');
  RegFunc('SIZEOF');

  { Fonctions mathematiques }
  RegFunc('ABS');        RegFunc('SQR');
  RegFunc('SQRT');       RegFunc('ROUND');
  RegFunc('TRUNC');      RegFunc('INT');
  RegFunc('FRAC');       RegFunc('SIN');
  RegFunc('COS');        RegFunc('LN');
  RegFunc('EXP');        RegFunc('PI');
  RegFunc('ARCTAN');

  { Fonctions de controle }
  RegProc('HALT');       RegProc('EXIT');
  RegProc('BREAK');      RegProc('CONTINUE');
  RegProc('RUNERROR');

  { Fonctions booleennes }
  RegFunc('ODD');        RegFunc('ASSIGNED');

  { Fonctions memoire }
  RegProc('FILLCHAR');   RegProc('MOVE');
  RegFunc('ADDR');       RegFunc('OFS');
  RegFunc('SEG');        RegFunc('CSEG');
  RegFunc('DSEG');       RegFunc('SSEG');
  RegFunc('SPTR');
  RegFunc('PARAMCOUNT'); RegFunc('PARAMSTR');

  { Fonctions sur les chaines }
  RegFunc('LENGTH');     RegFunc('COPY');
  RegFunc('POS');        RegFunc('CONCAT');
  RegFunc('UPCASE');
  RegProc('INSERT');     RegProc('DELETE');

  { Fichiers binaires }
  RegProc('BLOCKREAD');  RegProc('BLOCKWRITE');
  RegProc('ASSIGN');     RegProc('RESET');
  RegProc('REWRITE');    RegProc('CLOSE');
  RegFunc('EOF');        RegFunc('EOLN');
  RegFunc('IORESULT');   RegProc('SEEK');
  RegFunc('FILEPOS');    RegFunc('FILESIZE');
  RegProc('RENAME');     RegProc('ERASE');
  RegProc('APPEND');     RegProc('FLUSH');
  RegProc('SETTEXTBUF');

  { Repertoires }
  RegProc('MKDIR');      RegProc('RMDIR');
  RegProc('CHDIR');      RegProc('GETDIR');

  { Fonctions de conversion }
  RegFunc('LO');         RegFunc('HI');
  RegFunc('SWAP');

  { Fonctions diverses }
  RegFunc('RANDOM');     RegProc('RANDOMIZE');
  RegFunc('SIZEOF');

  { TP 5.5+ : POO (objets) }
  If TPVersionAtLeast(TP_VER_55) Then
  Begin
    RegFunc('TYPEOF');
  End;

  { TP 7+ : fonctions supplementaires }
  If TPVersionAtLeast(TP_VER_7) Then
  Begin
    RegFunc('ASSIGNED');
  End;
End;

{ ============================================================ }
{ TODO 06 - SYSTEME DE TYPES                      [IMPLEMENTE] }
{ ============================================================ }

{ ------------------------------------------------------------ }
{ TypeAdd : ajouter un type dans la table                      }
{ Retourne l index du type ajoute, ou -1 si plein              }
{ ------------------------------------------------------------ }

Function TypeAdd(Kind : TTypeKind; Const AName : TString;
                 ASize : Integer; AAlign : Integer;
                 AUnsigned : Boolean;
                 ABaseTypeIdx : Integer) : Integer;
Begin
  If TypeCount >= MAX_TYPE Then
  Begin
    WarnMsg('table des types pleine (MAX_TYPE=' +
      IntToStr_(MAX_TYPE) + ')');
    TypeAdd := -1;
    Exit;
  End;

  TypeTab[TypeCount].Kind        := Kind;
  TypeTab[TypeCount].Name        := StrUpperCase(AName);
  TypeTab[TypeCount].Size        := ASize;
  TypeTab[TypeCount].Align       := AAlign;
  TypeTab[TypeCount].BaseTypeIdx := ABaseTypeIdx;
  TypeTab[TypeCount].Lo          := 0;
  TypeTab[TypeCount].Hi          := 0;
  TypeTab[TypeCount].FieldCount  := 0;
  TypeTab[TypeCount].EnumCount   := 0;
  TypeTab[TypeCount].IsPacked    := False;
  TypeTab[TypeCount].IsUnsigned  := AUnsigned;

  TypeAdd := TypeCount;
  Inc(TypeCount);
End;

{ ------------------------------------------------------------ }
{ TypeInit : initialiser la table des types avec les types      }
{ primitifs de Turbo Pascal                                    }
{ ------------------------------------------------------------ }

Procedure TypeInit;
Var I : Integer;
Begin
  TypeCount := 0;

  { Initialiser toute la table a zero }
  For I := 0 To MAX_TYPE - 1 Do
  Begin
    TypeTab[I].Kind        := TYK_INTEGER;
    TypeTab[I].Name        := '';
    TypeTab[I].Size        := 0;
    TypeTab[I].Align       := 1;
    TypeTab[I].BaseTypeIdx := TY_UNKNOWN;
    TypeTab[I].Lo          := 0;
    TypeTab[I].Hi          := 0;
    TypeTab[I].FieldCount  := 0;
    TypeTab[I].EnumCount   := 0;
    TypeTab[I].IsPacked    := False;
    TypeTab[I].IsUnsigned  := False;
  End;

  { Types primitifs Turbo Pascal (Win32, 32 bits)                  }
  { Les index doivent correspondre aux constantes TY_IDX_xxx       }

  { idx 0 : Integer (LongInt 32 bits signe) }
  TypeAdd(TYK_INTEGER, 'INTEGER', 4, 4, False, TY_UNKNOWN);

  { idx 1 : Word (32 bits non signe en Win32) }
  TypeAdd(TYK_WORD, 'WORD', 4, 4, True, TY_UNKNOWN);

  { idx 2 : Byte (8 bits non signe) }
  TypeAdd(TYK_BYTE, 'BYTE', 1, 1, True, TY_UNKNOWN);

  { idx 3 : ShortInt (8 bits signe) }
  TypeAdd(TYK_SHORTINT, 'SHORTINT', 1, 1, False, TY_UNKNOWN);

  { idx 4 : Char (8 bits) }
  TypeAdd(TYK_CHAR, 'CHAR', 1, 1, True, TY_UNKNOWN);

  { idx 5 : Boolean (8 bits, 0 ou 1) }
  TypeAdd(TYK_BOOLEAN, 'BOOLEAN', 1, 1, True, TY_UNKNOWN);

  { idx 6 : String (ShortString, 256 octets: 1 longueur + 255 data) }
  TypeAdd(TYK_STRING, 'STRING', 256, 1, False, TY_UNKNOWN);

  { idx 7 : Real (stub entier 32 bits en Win32) }
  TypeAdd(TYK_REAL, 'REAL', 4, 4, False, TY_UNKNOWN);

  { idx 8 : Single (flottant IEEE 32 bits) }
  TypeAdd(TYK_SINGLE, 'SINGLE', 4, 4, False, TY_UNKNOWN);

  { idx 9 : Double (flottant IEEE 64 bits) }
  TypeAdd(TYK_DOUBLE, 'DOUBLE', 8, 4, False, TY_UNKNOWN);

  { idx 10 : Extended (flottant 80 bits) }
  TypeAdd(TYK_EXTENDED, 'EXTENDED', 10, 4, False, TY_UNKNOWN);

  { idx 11 : Comp (entier 64 bits virgule fixe) }
  TypeAdd(TYK_COMP, 'COMP', 8, 4, False, TY_UNKNOWN);

  { idx 12 : Pointer (pointeur generique 32 bits) }
  TypeAdd(TYK_POINTER, 'POINTER', 4, 4, False, TY_UNKNOWN);

  { idx 13 : PChar (pointeur vers Char) }
  TypeAdd(TYK_PCHAR, 'PCHAR', 4, 4, False, TY_IDX_CHAR);

  { idx 14 : Text (handle fichier texte) }
  TypeAdd(TYK_TEXT, 'TEXT', 4, 4, False, TY_UNKNOWN);

  { idx 15 : nil (constante pointeur nul) }
  TypeAdd(TYK_NIL, 'NIL', 4, 4, False, TY_UNKNOWN);

  { idx 16 : LongInt (alias de Integer en Win32) }
  TypeAdd(TYK_INTEGER, 'LONGINT', 4, 4, False, TY_IDX_INTEGER);

  { idx 17 : LongWord (TP8+, 32 bits non signe) }
  TypeAdd(TYK_WORD, 'LONGWORD', 4, 4, True, TY_IDX_WORD);

  If Opts.DebugMode Then
    WriteLn('  [TypeInit] ', TypeCount, ' types primitifs enregistres');
End;

{ ------------------------------------------------------------ }
{ TypeFindByName : trouver un type par son nom exact           }
{ Retourne l index ou -1 si non trouve                         }
{ ------------------------------------------------------------ }

Function TypeFindByName(Const AName : TString) : Integer;
Var
  I  : Integer;
  Up : TString;
Begin
  TypeFindByName := -1;
  Up := StrUpperCase(AName);
  For I := 0 To TypeCount - 1 Do
    If TypeTab[I].Name = Up Then
    Begin
      TypeFindByName := I;
      Exit;
    End;
End;

{ ------------------------------------------------------------ }
{ TypeSizeofIdx : retourne la taille d un type par son index   }
{ ------------------------------------------------------------ }

Function TypeSizeofIdx(Idx : Integer) : Integer;
Begin
  If (Idx >= 0) And (Idx < TypeCount) Then
    TypeSizeofIdx := TypeTab[Idx].Size
  Else
    TypeSizeofIdx := 4;  { taille par defaut = DWORD 32 bits }
End;

{ ------------------------------------------------------------ }
{ TypeResolve : resoudre un alias de type (BaseTypeIdx)        }
{ Suit la chaine BaseTypeIdx pour trouver le type reel         }
{ (ex: LongInt -> Integer)                                     }
{ Retourne l index du type final                               }
{ ------------------------------------------------------------ }

Function TypeResolve(Idx : Integer) : Integer;
Var
  Depth : Integer;
  Cur   : Integer;
Begin
  Cur   := Idx;
  Depth := 0;
  While (Cur >= 0) And (Cur < TypeCount) And (Depth < 32) Do
  Begin
    { Si pas d alias (BaseTypeIdx < 0), on est arrive }
    If TypeTab[Cur].BaseTypeIdx < 0 Then Break;

    { Si c est un type compose (pointeur, tableau, record, etc.) }
    { BaseTypeIdx designe le type element, pas un alias          }
    If TypeTab[Cur].Kind In [TYK_POINTER, TYK_PCHAR, TYK_ARRAY,
       TYK_RECORD, TYK_SET, TYK_ENUM, TYK_FILE,
       TYK_OBJECT, TYK_PROCVAR] Then Break;

    { Sinon c est un alias : suivre le lien }
    Cur := TypeTab[Cur].BaseTypeIdx;
    Inc(Depth);
  End;
  TypeResolve := Cur;
End;

{ ------------------------------------------------------------ }
{ TypeIsOrdinal : retourne True si le type est ordinal         }
{ (Integer, Word, Byte, ShortInt, Char, Boolean, Enum,         }
{  Subrange)                                                    }
{ ------------------------------------------------------------ }

Function TypeIsOrdinal(Idx : Integer) : Boolean;
Var R : Integer;
Begin
  R := TypeResolve(Idx);
  If (R < 0) Or (R >= TypeCount) Then
  Begin
    TypeIsOrdinal := False;
    Exit;
  End;
  Case TypeTab[R].Kind Of
    TYK_INTEGER, TYK_WORD, TYK_BYTE, TYK_SHORTINT,
    TYK_CHAR, TYK_BOOLEAN, TYK_ENUM, TYK_SUBRANGE :
      TypeIsOrdinal := True;
  Else
    TypeIsOrdinal := False;
  End;
End;

{ ------------------------------------------------------------ }
{ TypeIsNumeric : retourne True si le type est numerique       }
{ (tout ordinal + Real, Single, Double, Extended, Comp)        }
{ ------------------------------------------------------------ }

Function TypeIsNumeric(Idx : Integer) : Boolean;
Var R : Integer;
Begin
  R := TypeResolve(Idx);
  If (R < 0) Or (R >= TypeCount) Then
  Begin
    TypeIsNumeric := False;
    Exit;
  End;
  Case TypeTab[R].Kind Of
    TYK_INTEGER, TYK_WORD, TYK_BYTE, TYK_SHORTINT,
    TYK_CHAR, TYK_BOOLEAN, TYK_ENUM, TYK_SUBRANGE,
    TYK_REAL, TYK_SINGLE, TYK_DOUBLE, TYK_EXTENDED, TYK_COMP :
      TypeIsNumeric := True;
  Else
    TypeIsNumeric := False;
  End;
End;

{ ------------------------------------------------------------ }
{ TypeIsPointer : retourne True si le type est un pointeur     }
{ (Pointer, PChar, nil)                                        }
{ ------------------------------------------------------------ }

Function TypeIsPointer(Idx : Integer) : Boolean;
Var R : Integer;
Begin
  R := TypeResolve(Idx);
  If (R < 0) Or (R >= TypeCount) Then
  Begin
    TypeIsPointer := False;
    Exit;
  End;
  Case TypeTab[R].Kind Of
    TYK_POINTER, TYK_PCHAR, TYK_NIL :
      TypeIsPointer := True;
  Else
    TypeIsPointer := False;
  End;
End;

{ ------------------------------------------------------------ }
{ TypeIsString : retourne True si le type est une chaine       }
{ (String, PChar)                                              }
{ ------------------------------------------------------------ }

Function TypeIsString(Idx : Integer) : Boolean;
Var R : Integer;
Begin
  R := TypeResolve(Idx);
  If (R < 0) Or (R >= TypeCount) Then
  Begin
    TypeIsString := False;
    Exit;
  End;
  Case TypeTab[R].Kind Of
    TYK_STRING, TYK_PCHAR :
      TypeIsString := True;
  Else
    TypeIsString := False;
  End;
End;

{ ------------------------------------------------------------ }
{ TypeIsReal : retourne True si le type est un reel            }
{ (Real, Single, Double, Extended, Comp)                       }
{ ------------------------------------------------------------ }

Function TypeIsReal(Idx : Integer) : Boolean;
Var R : Integer;
Begin
  R := TypeResolve(Idx);
  If (R < 0) Or (R >= TypeCount) Then
  Begin
    TypeIsReal := False;
    Exit;
  End;
  Case TypeTab[R].Kind Of
    TYK_REAL, TYK_SINGLE, TYK_DOUBLE, TYK_EXTENDED, TYK_COMP :
      TypeIsReal := True;
  Else
    TypeIsReal := False;
  End;
End;

{ ------------------------------------------------------------ }
{ TypeCoerce : determine le type resultat d une operation       }
{ entre deux types (promotion Turbo Pascal)                    }
{ Retourne l index du type promu                               }
{ ------------------------------------------------------------ }

Function TypeCoerce(IdxA, IdxB : Integer) : Integer;
Var
  RA, RB : Integer;
  KA, KB : TTypeKind;
Begin
  RA := TypeResolve(IdxA);
  RB := TypeResolve(IdxB);

  { Si l un est invalide, retourner l autre }
  If (RA < 0) Or (RA >= TypeCount) Then
  Begin TypeCoerce := RB; Exit; End;
  If (RB < 0) Or (RB >= TypeCount) Then
  Begin TypeCoerce := RA; Exit; End;

  KA := TypeTab[RA].Kind;
  KB := TypeTab[RB].Kind;

  { Extended absorbe tout (sauf string) }
  If (KA = TYK_EXTENDED) Or (KB = TYK_EXTENDED) Then
  Begin TypeCoerce := TY_IDX_EXTENDED; Exit; End;

  { Double absorbe Real, Single, entiers }
  If (KA = TYK_DOUBLE) Or (KB = TYK_DOUBLE) Then
  Begin TypeCoerce := TY_IDX_DOUBLE; Exit; End;

  { Single absorbe Real, entiers }
  If (KA = TYK_SINGLE) Or (KB = TYK_SINGLE) Then
  Begin TypeCoerce := TY_IDX_SINGLE; Exit; End;

  { Comp absorbe entiers }
  If (KA = TYK_COMP) Or (KB = TYK_COMP) Then
  Begin TypeCoerce := TY_IDX_COMP; Exit; End;

  { Real absorbe entiers }
  If (KA = TYK_REAL) Or (KB = TYK_REAL) Then
  Begin TypeCoerce := TY_IDX_REAL; Exit; End;

  { Si un des deux est un pointeur, le resultat est un pointeur }
  If (KA In [TYK_POINTER, TYK_PCHAR]) Then
  Begin TypeCoerce := RA; Exit; End;
  If (KB In [TYK_POINTER, TYK_PCHAR]) Then
  Begin TypeCoerce := RB; Exit; End;

  { LongInt (Integer) absorbe Word, Byte, ShortInt }
  If (KA = TYK_INTEGER) Or (KB = TYK_INTEGER) Then
  Begin TypeCoerce := TY_IDX_INTEGER; Exit; End;

  { Word absorbe Byte }
  If (KA = TYK_WORD) Or (KB = TYK_WORD) Then
  Begin TypeCoerce := TY_IDX_WORD; Exit; End;

  { Sinon, promotion vers Integer }
  TypeCoerce := TY_IDX_INTEGER;
End;

{ ------------------------------------------------------------ }
{ TypeCompatible : verifie si une affectation dest := src est   }
{ compatible au sens Turbo Pascal                              }
{ Retourne True si compatible                                  }
{ ------------------------------------------------------------ }

Function TypeCompatible(IdxDest, IdxSrc : Integer) : Boolean;
Var
  RD, RS : Integer;
  KD, KS : TTypeKind;
Begin
  RD := TypeResolve(IdxDest);
  RS := TypeResolve(IdxSrc);

  { Types invalides : on accepte pour ne pas bloquer }
  If (RD < 0) Or (RD >= TypeCount) Or
     (RS < 0) Or (RS >= TypeCount) Then
  Begin
    TypeCompatible := True;
    Exit;
  End;

  { Meme type exact : toujours compatible }
  If RD = RS Then
  Begin
    TypeCompatible := True;
    Exit;
  End;

  KD := TypeTab[RD].Kind;
  KS := TypeTab[RS].Kind;

  { nil -> tout type pointeur ou PChar }
  If KS = TYK_NIL Then
  Begin
    TypeCompatible := (KD In [TYK_POINTER, TYK_PCHAR, TYK_NIL,
                              TYK_PROCVAR, TYK_OBJECT]);
    Exit;
  End;

  { Integer <-> Word (promotion implicite TP) }
  If ((KD = TYK_INTEGER) Or (KD = TYK_WORD)) And
     ((KS = TYK_INTEGER) Or (KS = TYK_WORD)) Then
  Begin
    TypeCompatible := True;
    Exit;
  End;

  { Byte/ShortInt -> Integer ou Word (promotion implicite) }
  If ((KS = TYK_BYTE) Or (KS = TYK_SHORTINT)) And
     ((KD = TYK_INTEGER) Or (KD = TYK_WORD) Or
      (KD = TYK_BYTE) Or (KD = TYK_SHORTINT)) Then
  Begin
    TypeCompatible := True;
    Exit;
  End;

  { Integer/Word -> Byte/ShortInt (retrecissement implicite TP) }
  If ((KD = TYK_BYTE) Or (KD = TYK_SHORTINT)) And
     ((KS = TYK_INTEGER) Or (KS = TYK_WORD)) Then
  Begin
    TypeCompatible := True;
    Exit;
  End;

  { Char -> String (promotion implicite TP) }
  If (KD = TYK_STRING) And (KS = TYK_CHAR) Then
  Begin
    TypeCompatible := True;
    Exit;
  End;

  { Boolean -> entier (en mode etendu $X+) }
  If ((KD = TYK_INTEGER) Or (KD = TYK_WORD) Or (KD = TYK_BYTE)) And
     (KS = TYK_BOOLEAN) Then
  Begin
    TypeCompatible := True;
    Exit;
  End;

  { Entier -> Boolean }
  If (KD = TYK_BOOLEAN) And
     ((KS = TYK_INTEGER) Or (KS = TYK_WORD) Or (KS = TYK_BYTE) Or
      (KS = TYK_SHORTINT)) Then
  Begin
    TypeCompatible := True;
    Exit;
  End;

  { Numerique vers numerique : toujours OK (avec conversion) }
  If TypeIsNumeric(RD) And TypeIsNumeric(RS) Then
  Begin
    TypeCompatible := True;
    Exit;
  End;

  { Pointeur vers pointeur : compatible (type generique) }
  If TypeIsPointer(RD) And TypeIsPointer(RS) Then
  Begin
    TypeCompatible := True;
    Exit;
  End;

  { PChar <-> String (en mode etendu $X+) }
  If ((KD = TYK_PCHAR) And (KS = TYK_STRING)) Or
     ((KD = TYK_STRING) And (KS = TYK_PCHAR)) Then
  Begin
    TypeCompatible := True;
    Exit;
  End;

  { Pointeur vers entier / entier vers pointeur (typecast) }
  If (TypeIsPointer(RD) And TypeIsOrdinal(RS)) Or
     (TypeIsOrdinal(RD) And TypeIsPointer(RS)) Then
  Begin
    TypeCompatible := True;
    Exit;
  End;

  { Enum -> Integer (Ord implicite) }
  If (KS = TYK_ENUM) And
     ((KD = TYK_INTEGER) Or (KD = TYK_WORD) Or (KD = TYK_BYTE)) Then
  Begin
    TypeCompatible := True;
    Exit;
  End;

  { Subrange : compatible avec son type de base }
  If (KD = TYK_SUBRANGE) Or (KS = TYK_SUBRANGE) Then
  Begin
    TypeCompatible := True;
    Exit;
  End;

  { Record/Object : compatibles seulement si meme nom }
  If (KD In [TYK_RECORD, TYK_OBJECT]) And (KD = KS) Then
  Begin
    TypeCompatible := (TypeTab[RD].Name = TypeTab[RS].Name);
    Exit;
  End;

  TypeCompatible := False;
End;

{ ============================================================ }
{ TODO 07 - EMETTEUR DE CODE ASM 80386            [IMPLEMENTE] }
{ ============================================================ }

Var
  { Compteur de labels interne a l emetteur }
  EmitLabelSeq    : Integer;
  { True si un programme principal est detecte }
  HasProgram      : Boolean;
  { Nombre d entrees DataTab deja emises }
  DataEmittedCount: Integer;

{ ------------------------------------------------------------ }
{ EmitOpen : ouvrir le fichier .ASM de sortie                  }
{ ------------------------------------------------------------ }

Procedure EmitOpen(Const AsmFile : TString);
Begin
  Assign(OutF, AsmFile);
  {$I-}
  Rewrite(OutF);
  {$I+}
  If IOResult <> 0 Then
    FatalError('impossible d''ouvrir le fichier de sortie: ' + AsmFile);
  OutFOpen := True;
  EmitLabelSeq := 0;
End;

{ ------------------------------------------------------------ }
{ EmitClose : fermer le fichier de sortie                      }
{ La directive END indique le point d entree du programme       }
{ ------------------------------------------------------------ }

Procedure EmitClose;
Begin
  If OutFOpen Then
  Begin
    If HasProgram Then
      WriteLn(OutF, 'END ' + TP_FUNC_PFX + 'Main')
    Else
      WriteLn(OutF, 'END');
    Close(OutF);
    OutFOpen := False;
  End;
End;

{ ------------------------------------------------------------ }
{ EmitRaw : ecrire une ligne brute dans le fichier de sortie   }
{ ------------------------------------------------------------ }

Procedure EmitRaw(Const S : TString);
Begin
  If OutFOpen Then
    WriteLn(OutF, S);
End;

{ ------------------------------------------------------------ }
{ EmitLabel : ecrire un label suivi de ':'                     }
{ ------------------------------------------------------------ }

Procedure EmitLabel(Const Lbl : TString);
Begin
  If OutFOpen Then
    WriteLn(OutF, Lbl, ':');
End;

{ ------------------------------------------------------------ }
{ EmitInstr : ecrire une instruction avec 8 espaces d indent   }
{ ------------------------------------------------------------ }

Procedure EmitInstr(Const S : TString);
Begin
  If OutFOpen Then
    WriteLn(OutF, '        ', S);
End;

{ ------------------------------------------------------------ }
{ EmitComment : ecrire un commentaire ('; text')               }
{ ------------------------------------------------------------ }

Procedure EmitComment(Const S : TString);
Begin
  If OutFOpen Then
    WriteLn(OutF, '; ', S);
End;

{ ------------------------------------------------------------ }
{ EmitBlankLine : ecrire une ligne vide                        }
{ ------------------------------------------------------------ }

Procedure EmitBlankLine;
Begin
  If OutFOpen Then
    WriteLn(OutF);
End;

{ ------------------------------------------------------------ }
{ LabelGen : generer un label unique _TPL_NNNNN               }
{ ------------------------------------------------------------ }

Function LabelGen : TString;
Begin
  Inc(EmitLabelSeq);
  LabelGen := TP_LBL_PFX + IntToStr_(EmitLabelSeq);
End;

{ ------------------------------------------------------------ }
{ EmitHeader : emettre l en-tete ASM pour un programme Win32   }
{ .386 / .MODEL FLAT, STDCALL / EXTRN imports Win32            }
{ ------------------------------------------------------------ }

Procedure EmitHeader;
Begin
  EmitComment('TPCW32 - Compilateur Turbo Pascal -> ASM 80386 Win32');
  EmitComment('Genere automatiquement a partir de : ' + Opts.SrcFile);
  EmitBlankLine;

  { Directive processeur et modele memoire }
  EmitRaw('.386');
  EmitRaw('.MODEL FLAT, STDCALL');
  EmitBlankLine;

  { Declarations externes (imports Win32 kernel32.dll) }
  EmitComment('--- Imports Win32 (kernel32.dll) ---');
  EmitRaw('EXTRN _ExitProcess@4:NEAR');
  EmitRaw('EXTRN _GetStdHandle@4:NEAR');
  EmitRaw('EXTRN _WriteFile@20:NEAR');
  EmitRaw('EXTRN _ReadFile@20:NEAR');
  EmitRaw('EXTRN _WriteConsoleA@20:NEAR');
  EmitRaw('EXTRN _ReadConsoleA@20:NEAR');
  EmitRaw('EXTRN _SetConsoleCursorPosition@8:NEAR');
  EmitRaw('EXTRN _GetConsoleScreenBufferInfo@8:NEAR');
  EmitRaw('EXTRN _SetConsoleTextAttribute@8:NEAR');
  EmitRaw('EXTRN _FillConsoleOutputCharacterA@20:NEAR');
  EmitRaw('EXTRN _FillConsoleOutputAttribute@20:NEAR');
  EmitRaw('EXTRN _GetConsoleMode@8:NEAR');
  EmitRaw('EXTRN _SetConsoleMode@8:NEAR');
  EmitRaw('EXTRN _GetProcessHeap@0:NEAR');
  EmitRaw('EXTRN _HeapAlloc@12:NEAR');
  EmitRaw('EXTRN _HeapFree@12:NEAR');
  EmitRaw('EXTRN _CreateFileA@28:NEAR');
  EmitRaw('EXTRN _CloseHandle@4:NEAR');
  EmitRaw('EXTRN _SetFilePointer@16:NEAR');
  EmitRaw('EXTRN _GetFileSize@8:NEAR');
  EmitRaw('EXTRN _DeleteFileA@4:NEAR');
  EmitRaw('EXTRN _CreateDirectoryA@8:NEAR');
  EmitRaw('EXTRN _RemoveDirectoryA@4:NEAR');
  EmitRaw('EXTRN _SetCurrentDirectoryA@4:NEAR');
  EmitRaw('EXTRN _GetCurrentDirectoryA@8:NEAR');
  EmitRaw('EXTRN _GetTickCount@0:NEAR');
  EmitRaw('EXTRN _Sleep@4:NEAR');
  EmitRaw('EXTRN _GetCommandLineA@0:NEAR');
  EmitBlankLine;
End;

{ ------------------------------------------------------------ }
{ EmitDataSeg : emettre le segment .DATA avec toutes les       }
{ entrees du DataTab (chaines, valeurs, tableaux, reserves)    }
{ et les variables runtime du compilateur                      }
{ ------------------------------------------------------------ }

Procedure EmitDataSeg;
Var
  I, J : Integer;
  S    : TString;
  C    : Char;
Begin
  EmitComment('--- Segment de donnees ---');
  EmitRaw('.DATA');
  EmitBlankLine;

  { Variables runtime internes du compilateur }
  EmitComment('--- Variables runtime TPCW32 ---');
  EmitRaw('HSTDOUT   DD 0');           { handle stdout         }
  EmitRaw('HSTDIN    DD 0');           { handle stdin          }
  EmitRaw('HHEAP     DD 0');           { handle heap           }
  EmitRaw('NUMBUF    DB 32 DUP(0)');   { buffer pour nombres   }
  EmitRaw('INBUF     DB 256 DUP(0)');  { buffer pour lecture    }
  EmitRaw('BYTESWR   DD 0');           { octets ecrits         }
  EmitRaw('BYTESRD   DD 0');           { octets lus            }
  EmitRaw('CRLF      DB 13,10,0');     { retour chariot        }
  EmitRaw('STRTMP    DB 256 DUP(0)');  { buffer temp chaine    }
  EmitRaw('STRBUF1   DB 256 DUP(0)');  { buffer concat/copy    }
  EmitRaw('STRBUF2   DB 256 DUP(0)');  { buffer concat/copy 2  }
  EmitRaw('TRUE_STR  DB ''TRUE'',0');   { chaine TRUE           }
  EmitRaw('FALSE_STR DB ''FALSE'',0');  { chaine FALSE          }
  EmitBlankLine;

  { Emettre toutes les entrees du pool de donnees }
  EmitComment('--- Constantes et donnees utilisateur ---');
  For I := DataEmittedCount To DataCount - 1 Do
  Begin
    Case DataTab[I].Kind Of
      DK_STR:
      Begin
        { Regrouper les caracteres imprimables dans des literals }
        { et les non-imprimables en valeurs numeriques           }
        S := '';
        J := 1;
        While J <= Length(DataTab[I].StrVal) Do
        Begin
          C := DataTab[I].StrVal[J];
          If (Ord(C) >= 32) And (Ord(C) < 127) And (C <> '''') Then
          Begin
            { Debut ou continuation d un groupe imprimable }
            If S <> '' Then
              S := S + ',';
            S := S + '''';
            While (J <= Length(DataTab[I].StrVal)) Do
            Begin
              C := DataTab[I].StrVal[J];
              If (Ord(C) >= 32) And (Ord(C) < 127) And (C <> '''') Then
              Begin
                S := S + C;
                Inc(J);
              End
              Else
                Break;
            End;
            S := S + '''';
          End
          Else
          Begin
            { Caractere non-imprimable -> valeur numerique }
            If S <> '' Then
              S := S + ',';
            S := S + IntToStr_(Ord(C));
            Inc(J);
          End;
        End;
        { Ajouter le terminateur nul }
        If S = '' Then
          S := '0'
        Else
          S := S + ',0';
        EmitRaw(DataTab[I].LblName + '  DB ' + S);
      End;

      DK_DWORD:
      Begin
        EmitRaw(DataTab[I].LblName + '  DD ' +
                IntToStr_(DataTab[I].IntVal));
      End;

      DK_BYTE:
      Begin
        EmitRaw(DataTab[I].LblName + '  DB ' +
                IntToStr_(DataTab[I].IntVal));
      End;

      DK_ARRAY:
      Begin
        If DataTab[I].ElemSize = 1 Then
          EmitRaw(DataTab[I].LblName + '  DB ' +
                  IntToStr_(DataTab[I].ElemCount) + ' DUP(0)')
        Else
          EmitRaw(DataTab[I].LblName + '  DB ' +
                  IntToStr_(DataTab[I].ElemCount * DataTab[I].ElemSize) +
                  ' DUP(0)');
      End;

      DK_RES:
      Begin
        EmitRaw(DataTab[I].LblName + '  DB ' +
                IntToStr_(DataTab[I].IntVal) + ' DUP(0)');
      End;

      DK_STRUCT:
      Begin
        { Structure : DB Size DUP(0) }
        If DataTab[I].IntVal > 0 Then
          EmitRaw(DataTab[I].LblName + '  DB ' +
                  IntToStr_(DataTab[I].IntVal) + ' DUP(0)')
        Else
          EmitRaw(DataTab[I].LblName + '  DD 0');
      End;

      DK_ZERO:
      Begin
        { Espace initialise a zero : DB Size DUP(0) }
        If DataTab[I].IntVal > 0 Then
          EmitRaw(DataTab[I].LblName + '  DB ' +
                  IntToStr_(DataTab[I].IntVal) + ' DUP(0)')
        Else
          EmitRaw(DataTab[I].LblName + '  DD 0');
      End;
    End; { case }
  End;
  EmitBlankLine;
  DataEmittedCount := DataCount;
End;

{ ------------------------------------------------------------ }
{ EmitCodeSeg : emettre le debut du segment .CODE              }
{ ------------------------------------------------------------ }

Procedure EmitCodeSeg;
Begin
  EmitComment('--- Segment de code ---');
  EmitRaw('.CODE');
  EmitBlankLine;
End;

{ ------------------------------------------------------------ }
{ EmitProlog : emettre le prologue d une fonction/procedure     }
{ PUSH EBP / MOV EBP,ESP / SUB ESP,locals                     }
{ ------------------------------------------------------------ }

Procedure EmitProlog(LocalSize : Integer);
Begin
  EmitInstr('PUSH EBP');
  EmitInstr('MOV EBP,ESP');
  If LocalSize > 0 Then
    EmitInstr('SUB ESP,' + IntToStr_(LocalSize));
End;

{ ------------------------------------------------------------ }
{ EmitEpilog : emettre l epilogue d une fonction/procedure      }
{ MOV ESP,EBP / POP EBP / RET                                 }
{ ------------------------------------------------------------ }

Procedure EmitEpilog;
Begin
  EmitInstr('MOV ESP,EBP');
  EmitInstr('POP EBP');
  EmitInstr('RET');
End;

{ ============================================================ }
{ TODO 08 - SEGMENT DE DONNEES ET STATIQUES    [IMPLEMENTE]    }
{ ============================================================ }

{ ------------------------------------------------------------ }
{ StaticVarSeq : compteur pour generer des labels statiques    }
{ uniques de la forme _TPST_1, _TPST_2, ...                   }
{ ------------------------------------------------------------ }

Var
  StaticVarSeq : Integer;

{ ------------------------------------------------------------ }
{ DataAddGlobalVar : creer une entree dans le DataTab pour une }
{ variable globale Pascal avec label _TPV_nom                  }
{ TypeName est le nom du type (INTEGER, CHAR, etc.)            }
{ Retourne l index dans DataTab ou -1                          }
{ ------------------------------------------------------------ }

Function DataAddGlobalVar(Const Name : TString;
                          Const TypeName : TString;
                          InitVal : LongInt) : Integer;
Var
  Lbl : TString;
  Up  : TString;
  Sz  : Integer;
Begin
  Lbl := TP_VAR_PFX + StrUpperCase(Name);
  Up  := StrUpperCase(TypeName);
  Sz  := TPTypeSizeof(Up);
  If Sz < 0 Then Sz := 4; { defaut : 32 bits }

  { Chaine (STRING) : DB 256 DUP(0) }
  If Up = 'STRING' Then
  Begin
    DataAddGlobalVar := DataAdd(Lbl, DK_ARRAY, 0, '', 256, 1);
    Exit;
  End;

  { Type 1 octet : CHAR, BOOLEAN, BYTE, SHORTINT }
  If Sz = 1 Then
  Begin
    DataAddGlobalVar := DataAddByte(Lbl, InitVal);
    Exit;
  End;

  { Type 2 octets : WORD (en 16-bit, mais Win32 = 4 en general) }
  { Type 4 octets : INTEGER, LONGINT, POINTER, PCHAR, TEXT }
  { Type 8 octets : DOUBLE, COMP }
  { Type 10 octets : EXTENDED }
  If Sz <= 4 Then
    DataAddGlobalVar := DataAddDWord(Lbl, InitVal)
  Else
    DataAddGlobalVar := DataAddRes(Lbl, Sz);
End;

{ ------------------------------------------------------------ }
{ DataAddTypedConst : creer une entree dans le DataTab pour    }
{ une constante typee (CONST x: Integer = 42)                 }
{ avec label _TPV_nom et valeur initiale                      }
{ Retourne l index dans DataTab ou -1                          }
{ ------------------------------------------------------------ }

Function DataAddTypedConst(Const Name : TString;
                           Const TypeName : TString;
                           InitVal : LongInt;
                           Const InitStr : TString) : Integer;
Var
  Lbl : TString;
  Up  : TString;
  Sz  : Integer;
Begin
  Lbl := TP_VAR_PFX + StrUpperCase(Name);
  Up  := StrUpperCase(TypeName);
  Sz  := TPTypeSizeof(Up);
  If Sz < 0 Then Sz := 4;

  { Chaine (STRING) : DB 'contenu',0 }
  If (Up = 'STRING') Or (Up = 'PCHAR') Then
  Begin
    If InitStr <> '' Then
      DataAddTypedConst := DataAdd(Lbl, DK_STR, 0, InitStr, 0, 0)
    Else
      DataAddTypedConst := DataAdd(Lbl, DK_ARRAY, 0, '', 256, 1);
    Exit;
  End;

  { Type 1 octet : CHAR, BOOLEAN, BYTE, SHORTINT }
  If Sz = 1 Then
  Begin
    DataAddTypedConst := DataAddByte(Lbl, InitVal);
    Exit;
  End;

  { Type 4 octets et plus }
  If Sz <= 4 Then
    DataAddTypedConst := DataAddDWord(Lbl, InitVal)
  Else
    DataAddTypedConst := DataAddRes(Lbl, Sz);
End;

{ ------------------------------------------------------------ }
{ DataAddStaticVar : creer une variable statique avec un label }
{ unique _TPST_N (pour variables locales statiques)            }
{ Retourne le label genere                                     }
{ ------------------------------------------------------------ }

Function DataAddStaticVar(Const TypeName : TString;
                          InitVal : LongInt) : TString;
Var
  Lbl : TString;
  Up  : TString;
  Sz  : Integer;
Begin
  Inc(StaticVarSeq);
  Lbl := TP_STA_PFX + IntToStr_(StaticVarSeq);
  Up  := StrUpperCase(TypeName);
  Sz  := TPTypeSizeof(Up);
  If Sz < 0 Then Sz := 4;

  If Up = 'STRING' Then
    DataAdd(Lbl, DK_ARRAY, 0, '', 256, 1)
  Else If Sz = 1 Then
    DataAddByte(Lbl, InitVal)
  Else If Sz <= 4 Then
    DataAddDWord(Lbl, InitVal)
  Else
    DataAddRes(Lbl, Sz);

  DataAddStaticVar := Lbl;
End;

{ ------------------------------------------------------------ }
{ ParseDataDecls : scanner le TokenPool pour trouver les       }
{ sections VAR et CONST au niveau global (scope 0).            }
{ Cree les entrees DataTab et enregistre les symboles.         }
{ Appele avant EmitDataSeg.                                    }
{ ------------------------------------------------------------ }

{ Forward declaration pour SkipToMatchingEnd (TODO 09) }
Procedure SkipToMatchingEnd(Var I : Integer); Forward;

Procedure ParseDataDecls;
Var
  I       : Integer;
  Depth   : Integer;  { profondeur BEGIN/END }
  Names   : Array[0..63] Of TString;
  NCount  : Integer;
  TName   : TString;
  TIdx    : Integer;
  DIdx    : Integer;
  SIdx    : Integer;
  J       : Integer;
  InitVal : LongInt;
  InitStr : TString;
  VName   : TString;
  Up      : TString;
  ArrLo   : LongInt;
  ArrHi   : LongInt;
  ArrElem : LongInt;
  ElemType: TString;
  ElemSz  : Integer;
  FOfs    : Integer;
  FC      : Integer;
  FName   : TString;
  FTName  : TString;
  FTIdx   : Integer;
  FSz     : Integer;
  BaseTN  : TString;
  BTIdx   : Integer;
Begin
  I := 0;
  Depth := 0;

  While I < TokenCount Do
  Begin
    { Suivre la profondeur BEGIN/END pour rester au niveau global }
    If (TokenPool[I].Kind = TK_KEYWORD) Then
    Begin
      Up := StrUpperCase(TokenPool[I].Val);

      { Incrémenter depth sur BEGIN, RECORD, CASE, REPEAT }
      If (Up = 'BEGIN') Or (Up = 'RECORD') Or (Up = 'REPEAT') Or
         (Up = 'ASM') Then
      Begin
        Inc(Depth);
        Inc(I);
        Continue;
      End;

      { Décrémenter depth sur END }
      If Up = 'END' Then
      Begin
        If Depth > 0 Then
          Dec(Depth);
        Inc(I);
        Continue;
      End;

      { UNTIL ne change pas le depth mais c'est la fin d'un REPEAT }
      If Up = 'UNTIL' Then
      Begin
        If Depth > 0 Then
          Dec(Depth);
        Inc(I);
        Continue;
      End;

      { Si on est dans un bloc imbrique, avancer sans traiter }
      If Depth > 0 Then
      Begin
        Inc(I);
        Continue;
      End;

      { ====== Traitement au niveau global (Depth = 0) ====== }

      { --- Section VAR --- }
      If Up = 'VAR' Then
      Begin
        Inc(I); { sauter 'VAR' }

        { Parser les declarations de variables }
        { Format: name1, name2 : TypeName; name3 : TypeName; ... }
        While I < TokenCount Do
        Begin
          { Si on rencontre un mot-cle de section ou BEGIN, sortir }
          If (TokenPool[I].Kind = TK_KEYWORD) Then
          Begin
            Up := StrUpperCase(TokenPool[I].Val);
            If (Up = 'VAR') Or (Up = 'CONST') Or (Up = 'TYPE') Or
               (Up = 'PROCEDURE') Or (Up = 'FUNCTION') Or
               (Up = 'BEGIN') Or (Up = 'LABEL') Or
               (Up = 'USES') Or (Up = 'PROGRAM') Then
              Break;
          End;

          { Collecter les noms de variables (separes par des virgules) }
          NCount := 0;
          While (I < TokenCount) And
                (TokenPool[I].Kind = TK_IDENT) Do
          Begin
            If NCount < 64 Then
            Begin
              Names[NCount] := StrUpperCase(TokenPool[I].Val);
              Inc(NCount);
            End;
            Inc(I);
            { Si virgule, continuer a collecter }
            If (I < TokenCount) And (TokenPool[I].Kind = TK_PUNCT) And
               (TokenPool[I].Val = ',') Then
              Inc(I)  { sauter la virgule }
            Else
              Break;
          End;

          { Si aucun nom collecte, avancer et essayer encore }
          If NCount = 0 Then
          Begin
            Inc(I);
            Continue;
          End;

          { Attendre ':' }
          If (I < TokenCount) And (TokenPool[I].Kind = TK_PUNCT) And
             (TokenPool[I].Val = ':') Then
            Inc(I) { sauter ':' }
          Else
          Begin
            { Pas de ':' -> erreur de syntaxe, avancer au ';' }
            While (I < TokenCount) And
                  Not ((TokenPool[I].Kind = TK_PUNCT) And
                       (TokenPool[I].Val = ';')) Do
              Inc(I);
            If I < TokenCount Then Inc(I);
            Continue;
          End;

          { Lire le type }
          TName := '';
          TIdx  := -1;

          { Verifier si c'est ARRAY[lo..hi] OF TypeElem }
          If (I < TokenCount) And (TokenPool[I].Kind = TK_KEYWORD) And
             (StrUpperCase(TokenPool[I].Val) = 'ARRAY') Then
          Begin
            Inc(I); { sauter 'ARRAY' }
            ArrLo := 0;
            ArrHi := 0;
            ElemType := 'INTEGER';

            { Attendre '[' }
            If (I < TokenCount) And (TokenPool[I].Kind = TK_PUNCT) And
               (TokenPool[I].Val = '[') Then
            Begin
              Inc(I); { sauter '[' }
              { Lire borne basse }
              If (I < TokenCount) And (TokenPool[I].Kind = TK_INTEGER) Then
              Begin
                ArrLo := TokenPool[I].IntVal;
                Inc(I);
              End;
              { Attendre '..' }
              If (I < TokenCount) And (TokenPool[I].Kind = TK_PUNCT) And
                 (TokenPool[I].Val = '..') Then
                Inc(I);
              { Lire borne haute }
              If (I < TokenCount) And (TokenPool[I].Kind = TK_INTEGER) Then
              Begin
                ArrHi := TokenPool[I].IntVal;
                Inc(I);
              End;
              { Attendre ']' }
              If (I < TokenCount) And (TokenPool[I].Kind = TK_PUNCT) And
                 (TokenPool[I].Val = ']') Then
                Inc(I);
            End;
            { Attendre 'OF' }
            If (I < TokenCount) And (TokenPool[I].Kind = TK_KEYWORD) And
               (StrUpperCase(TokenPool[I].Val) = 'OF') Then
              Inc(I);
            { Lire le type d element }
            If (I < TokenCount) And
               ((TokenPool[I].Kind = TK_IDENT) Or
                (TokenPool[I].Kind = TK_KEYWORD)) Then
            Begin
              ElemType := StrUpperCase(TokenPool[I].Val);
              Inc(I);
            End;

            ArrElem := ArrHi - ArrLo + 1;
            If ArrElem < 1 Then ArrElem := 1;
            ElemSz := TPTypeSizeof(ElemType);
            If ElemSz < 0 Then
            Begin
              BTIdx := TypeFindByName(ElemType);
              If BTIdx >= 0 Then ElemSz := TypeTab[BTIdx].Size
              Else ElemSz := 4;
            End;

            { Creer un type tableau anonyme }
            TIdx := TypeAdd(TYK_ARRAY, '', ArrElem * ElemSz, 4, False, -1);
            If TIdx >= 0 Then
            Begin
              TypeTab[TIdx].Lo := ArrLo;
              TypeTab[TIdx].Hi := ArrHi;
              BTIdx := TypeFindByName(ElemType);
              If BTIdx < 0 Then BTIdx := TY_IDX_INTEGER;
              TypeTab[TIdx].BaseTypeIdx := BTIdx;
            End;

            { Creer une entree tableau pour chaque variable }
            For J := 0 To NCount - 1 Do
            Begin
              DIdx := DataAddArray(TP_VAR_PFX + Names[J],
                                    ArrElem, ElemSz);
              SIdx := SymAdd(Names[J], SK_VAR, TIdx);
              If SIdx >= 0 Then
              Begin
                SymTab[SIdx].IsGlobal := True;
                SymTab[SIdx].Offset   := DIdx;
              End;
            End;

            { Avancer au ';' }
            While (I < TokenCount) And
                  Not ((TokenPool[I].Kind = TK_PUNCT) And
                       (TokenPool[I].Val = ';')) Do
              Inc(I);
            If I < TokenCount Then Inc(I);
            Continue;
          End;

          { Verifier si c'est RECORD ... END }
          If (I < TokenCount) And (TokenPool[I].Kind = TK_KEYWORD) And
             (StrUpperCase(TokenPool[I].Val) = 'RECORD') Then
          Begin
            Inc(I);
            { Creer un type record anonyme }
            TIdx := TypeAdd(TYK_RECORD, '', 0, 4, False, -1);
            FOfs := 0;
            FC := 0;

            While I < TokenCount Do
            Begin
              If (TokenPool[I].Kind = TK_KEYWORD) And
                 (StrUpperCase(TokenPool[I].Val) = 'END') Then
              Begin
                Inc(I);
                Break;
              End;
              If TokenPool[I].Kind <> TK_IDENT Then
              Begin
                Inc(I);
                Continue;
              End;
              FName := StrUpperCase(TokenPool[I].Val);
              Inc(I);
              If (I < TokenCount) And (TokenPool[I].Kind = TK_PUNCT) And
                 (TokenPool[I].Val = ':') Then
                Inc(I);
              FTName := 'INTEGER';
              If (I < TokenCount) And
                 ((TokenPool[I].Kind = TK_IDENT) Or
                  (TokenPool[I].Kind = TK_KEYWORD)) Then
              Begin
                FTName := StrUpperCase(TokenPool[I].Val);
                Inc(I);
              End;
              FSz := TPTypeSizeof(FTName);
              If FSz < 0 Then
              Begin
                FTIdx := TypeFindByName(FTName);
                If FTIdx >= 0 Then FSz := TypeTab[FTIdx].Size
                Else FSz := 4;
              End;
              FTIdx := TypeFindByName(FTName);
              If FTIdx < 0 Then FTIdx := TY_IDX_INTEGER;
              If (TIdx >= 0) And (FC < MAX_FIELDS) Then
              Begin
                TypeTab[TIdx].Fields[FC].Name    := FName;
                TypeTab[TIdx].Fields[FC].TypeIdx := FTIdx;
                TypeTab[TIdx].Fields[FC].Offset  := FOfs;
                Inc(FC);
                TypeTab[TIdx].FieldCount := FC;
                FOfs := FOfs + FSz;
                TypeTab[TIdx].Size := FOfs;
              End;
              If (I < TokenCount) And (TokenPool[I].Kind = TK_PUNCT) And
                 (TokenPool[I].Val = ';') Then
                Inc(I);
            End;

            For J := 0 To NCount - 1 Do
            Begin
              DIdx := DataAddStruct(TP_VAR_PFX + Names[J], FOfs);
              SIdx := SymAdd(Names[J], SK_VAR, TIdx);
              If SIdx >= 0 Then
              Begin
                SymTab[SIdx].IsGlobal := True;
                SymTab[SIdx].Offset   := DIdx;
              End;
            End;

            While (I < TokenCount) And
                  Not ((TokenPool[I].Kind = TK_PUNCT) And
                       (TokenPool[I].Val = ';')) Do
              Inc(I);
            If I < TokenCount Then Inc(I);
            Continue;
          End;

          { Verifier si c'est SET OF T }
          If (I < TokenCount) And (TokenPool[I].Kind = TK_KEYWORD) And
             (StrUpperCase(TokenPool[I].Val) = 'SET') Then
          Begin
            Inc(I);
            If (I < TokenCount) And (TokenPool[I].Kind = TK_KEYWORD) And
               (StrUpperCase(TokenPool[I].Val) = 'OF') Then
              Inc(I);
            BaseTN := 'BYTE';
            If (I < TokenCount) And
               ((TokenPool[I].Kind = TK_IDENT) Or
                (TokenPool[I].Kind = TK_KEYWORD)) Then
            Begin
              BaseTN := StrUpperCase(TokenPool[I].Val);
              Inc(I);
            End;
            BTIdx := TypeFindByName(BaseTN);
            If BTIdx < 0 Then BTIdx := TY_IDX_BYTE;
            TIdx := TypeAdd(TYK_SET, '', 32, 4, False, BTIdx);

            For J := 0 To NCount - 1 Do
            Begin
              DIdx := DataAddStruct(TP_VAR_PFX + Names[J], 32);
              SIdx := SymAdd(Names[J], SK_VAR, TIdx);
              If SIdx >= 0 Then
              Begin
                SymTab[SIdx].IsGlobal := True;
                SymTab[SIdx].Offset   := DIdx;
              End;
            End;

            While (I < TokenCount) And
                  Not ((TokenPool[I].Kind = TK_PUNCT) And
                       (TokenPool[I].Val = ';')) Do
              Inc(I);
            If I < TokenCount Then Inc(I);
            Continue;
          End;

          { Type simple : lire un identifiant ou mot-cle }
          If (I < TokenCount) And
             ((TokenPool[I].Kind = TK_IDENT) Or
              (TokenPool[I].Kind = TK_KEYWORD)) Then
          Begin
            TName := StrUpperCase(TokenPool[I].Val);
            Inc(I);
          End;

          { Verifier type pointeur ^Type }
          If (I < TokenCount) And (TName = '') And
             (TokenPool[I].Kind = TK_OP) And
             (TokenPool[I].Val = '^') Then
          Begin
            Inc(I); { sauter '^' }
            If (I < TokenCount) And
               ((TokenPool[I].Kind = TK_IDENT) Or
                (TokenPool[I].Kind = TK_KEYWORD)) Then
            Begin
              TName := '^' + StrUpperCase(TokenPool[I].Val);
              Inc(I);
            End
            Else
              TName := 'POINTER';
          End;

          If TName = '' Then TName := 'INTEGER';

          { Trouver le type dans TypeTab }
          TIdx := TypeFindByName(TName);

          { Creer les entrees DataTab et SymTab pour chaque variable }
          For J := 0 To NCount - 1 Do
          Begin
            { Utiliser DataAddStruct pour les types structures }
            If (TIdx >= 0) And (TIdx < TypeCount) And
               ((TypeTab[TIdx].Kind = TYK_RECORD) Or
                (TypeTab[TIdx].Kind = TYK_OBJECT) Or
                (TypeTab[TIdx].Kind = TYK_SET)) Then
              DIdx := DataAddStruct(TP_VAR_PFX + Names[J], TypeTab[TIdx].Size)
            Else If (TIdx >= 0) And (TIdx < TypeCount) And
                    (TypeTab[TIdx].Kind = TYK_ARRAY) Then
              DIdx := DataAddArray(TP_VAR_PFX + Names[J],
                TypeTab[TIdx].Hi - TypeTab[TIdx].Lo + 1,
                TypeSizeofIdx(TypeTab[TIdx].BaseTypeIdx))
            Else
              DIdx := DataAddGlobalVar(Names[J], TName, 0);
            SIdx := SymAdd(Names[J], SK_VAR, TIdx);
            If SIdx >= 0 Then
            Begin
              SymTab[SIdx].IsGlobal := True;
              SymTab[SIdx].Offset   := DIdx;
            End;
          End;

          { Avancer au ';' }
          While (I < TokenCount) And
                Not ((TokenPool[I].Kind = TK_PUNCT) And
                     (TokenPool[I].Val = ';')) Do
            Inc(I);
          If I < TokenCount Then Inc(I);
        End; { while parsing VAR block }
        Continue;
      End; { VAR }

      { --- Section CONST --- }
      If Up = 'CONST' Then
      Begin
        Inc(I); { sauter 'CONST' }

        { Parser les declarations de constantes }
        While I < TokenCount Do
        Begin
          { Si on rencontre un mot-cle de section, sortir }
          If (TokenPool[I].Kind = TK_KEYWORD) Then
          Begin
            Up := StrUpperCase(TokenPool[I].Val);
            If (Up = 'VAR') Or (Up = 'CONST') Or (Up = 'TYPE') Or
               (Up = 'PROCEDURE') Or (Up = 'FUNCTION') Or
               (Up = 'BEGIN') Or (Up = 'LABEL') Or
               (Up = 'USES') Or (Up = 'PROGRAM') Then
              Break;
          End;

          { Lire le nom de la constante }
          If (TokenPool[I].Kind <> TK_IDENT) Then
          Begin
            Inc(I);
            Continue;
          End;
          VName := StrUpperCase(TokenPool[I].Val);
          Inc(I);

          { Determiner si c est une constante typee (nom : Type = val) }
          { ou non-typee (nom = val) }
          TName := '';
          InitVal := 0;
          InitStr := '';

          If (I < TokenCount) And (TokenPool[I].Kind = TK_PUNCT) And
             (TokenPool[I].Val = ':') Then
          Begin
            { Constante typee : nom : Type = val }
            Inc(I); { sauter ':' }

            { Lire le type }
            If (I < TokenCount) And
               ((TokenPool[I].Kind = TK_IDENT) Or
                (TokenPool[I].Kind = TK_KEYWORD)) Then
            Begin
              TName := StrUpperCase(TokenPool[I].Val);
              Inc(I);
            End;

            { Attendre '=' }
            If (I < TokenCount) And (TokenPool[I].Kind = TK_OP) And
               (TokenPool[I].Val = '=') Then
              Inc(I);

            { Lire la valeur }
            If (I < TokenCount) Then
            Begin
              If (TokenPool[I].Kind = TK_INTEGER) Then
              Begin
                InitVal := TokenPool[I].IntVal;
                Inc(I);
              End
              Else If (TokenPool[I].Kind = TK_CHAR) Then
              Begin
                InitVal := TokenPool[I].IntVal;
                Inc(I);
              End
              Else If (TokenPool[I].Kind = TK_STRING) Then
              Begin
                InitStr := TokenPool[I].Val;
                { Si le type est CHAR et la valeur est un seul caractere }
                If (TName = 'CHAR') And (Length(InitStr) = 1) Then
                Begin
                  InitVal := Ord(InitStr[1]);
                  InitStr := '';
                End;
                Inc(I);
              End
              Else If (TokenPool[I].Kind = TK_KEYWORD) Then
              Begin
                Up := StrUpperCase(TokenPool[I].Val);
                If Up = 'TRUE' Then
                  InitVal := 1
                Else If Up = 'FALSE' Then
                  InitVal := 0
                Else If Up = 'NIL' Then
                  InitVal := 0;
                Inc(I);
              End
              Else If (TokenPool[I].Kind = TK_IDENT) Then
              Begin
                { Peut etre une constante nommee deja definie }
                SIdx := SymFind(TokenPool[I].Val);
                If (SIdx >= 0) And (SymTab[SIdx].Kind = SK_CONST) Then
                  InitVal := SymTab[SIdx].ImmVal;
                Inc(I);
              End
              Else If (TokenPool[I].Kind = TK_OP) And
                      (TokenPool[I].Val = '-') Then
              Begin
                { Valeur negative }
                Inc(I);
                If (I < TokenCount) And
                   (TokenPool[I].Kind = TK_INTEGER) Then
                Begin
                  InitVal := -TokenPool[I].IntVal;
                  Inc(I);
                End;
              End;
            End;

            TIdx := TypeFindByName(TName);

            { Creer l entree DataTab }
            If InitStr <> '' Then
              DIdx := DataAddTypedConst(VName, TName, InitVal, InitStr)
            Else
              DIdx := DataAddTypedConst(VName, TName, InitVal, '');

            { Enregistrer dans SymTab comme SK_CONST }
            SIdx := SymAdd(VName, SK_CONST, TIdx);
            If SIdx >= 0 Then
            Begin
              SymTab[SIdx].IsGlobal := True;
              SymTab[SIdx].ImmVal   := InitVal;
              SymTab[SIdx].Offset   := DIdx;
            End;
          End
          Else If (I < TokenCount) And (TokenPool[I].Kind = TK_OP) And
                  (TokenPool[I].Val = '=') Then
          Begin
            { Constante non-typee : nom = val }
            Inc(I); { sauter '=' }
            InitVal := 0;
            InitStr := '';

            If (I < TokenCount) Then
            Begin
              If (TokenPool[I].Kind = TK_INTEGER) Then
              Begin
                InitVal := TokenPool[I].IntVal;
                Inc(I);
              End
              Else If (TokenPool[I].Kind = TK_CHAR) Then
              Begin
                InitVal := TokenPool[I].IntVal;
                Inc(I);
              End
              Else If (TokenPool[I].Kind = TK_STRING) Then
              Begin
                InitStr := TokenPool[I].Val;
                Inc(I);
              End
              Else If (TokenPool[I].Kind = TK_KEYWORD) Then
              Begin
                Up := StrUpperCase(TokenPool[I].Val);
                If Up = 'TRUE' Then
                  InitVal := 1
                Else If Up = 'FALSE' Then
                  InitVal := 0
                Else If Up = 'NIL' Then
                  InitVal := 0
                Else If Up = 'MAXINT' Then
                  InitVal := 2147483647;
                Inc(I);
              End
              Else If (TokenPool[I].Kind = TK_IDENT) Then
              Begin
                { Peut etre une constante nommee }
                SIdx := SymFind(TokenPool[I].Val);
                If (SIdx >= 0) And (SymTab[SIdx].Kind = SK_CONST) Then
                  InitVal := SymTab[SIdx].ImmVal;
                Inc(I);
              End
              Else If (TokenPool[I].Kind = TK_OP) And
                      (TokenPool[I].Val = '-') Then
              Begin
                Inc(I);
                If (I < TokenCount) And
                   (TokenPool[I].Kind = TK_INTEGER) Then
                Begin
                  InitVal := -TokenPool[I].IntVal;
                  Inc(I);
                End;
              End
              Else If (TokenPool[I].Kind = TK_REAL) Then
              Begin
                { Constante reelle : stocker la partie entiere }
                InitVal := Trunc(TokenPool[I].RealVal);
                Inc(I);
              End;
            End;

            { Constante non-typee : juste registrer dans SymTab }
            SIdx := SymAdd(VName, SK_CONST, -1);
            If SIdx >= 0 Then
            Begin
              SymTab[SIdx].IsGlobal := True;
              SymTab[SIdx].ImmVal   := InitVal;
            End;
          End;

          { Avancer au ';' }
          While (I < TokenCount) And
                Not ((TokenPool[I].Kind = TK_PUNCT) And
                     (TokenPool[I].Val = ';')) Do
            Inc(I);
          If I < TokenCount Then Inc(I);
        End; { while parsing CONST block }
        Continue;
      End; { CONST }

      { --- Section PROCEDURE ou FUNCTION : sauter entierement --- }
      If (Up = 'PROCEDURE') Or (Up = 'FUNCTION') Then
      Begin
        { Avancer jusqu au BEGIN puis au END correspondant }
        Inc(I);
        While (I < TokenCount) Do
        Begin
          If ((TokenPool[I].Kind = TK_KEYWORD) Or
              (TokenPool[I].Kind = TK_IDENT)) And
             (StrUpperCase(TokenPool[I].Val) = 'FORWARD') Then
          Begin
            { Declaration FORWARD : avancer jusqu au ';' }
            Inc(I);
            While (I < TokenCount) And
                  Not ((TokenPool[I].Kind = TK_PUNCT) And
                       (TokenPool[I].Val = ';')) Do
              Inc(I);
            If I < TokenCount Then Inc(I);
            Break;
          End;
          If (TokenPool[I].Kind = TK_KEYWORD) And
             (StrUpperCase(TokenPool[I].Val) = 'BEGIN') Then
          Begin
            Inc(I);
            SkipToMatchingEnd(I);
            { Sauter le ';' apres END }
            If (I < TokenCount) And (TokenPool[I].Kind = TK_PUNCT) And
               (TokenPool[I].Val = ';') Then
              Inc(I);
            Break;
          End;
          Inc(I);
        End;
        Continue;
      End;

    End; { if keyword }

    { Avancer au token suivant }
    Inc(I);
  End; { while I < TokenCount }
End;

{ ============================================================ }
{ TODO 09 - VARIABLES ET AFFECTATIONS              [IMPLEMENTE] }
{ ============================================================ }

Const
  MAX_PROC  = {$IFDEF FPC}256{$ELSE}32{$ENDIF};   { max procedures/fonctions }
  MAX_LOCAL = {$IFDEF FPC}64{$ELSE}16{$ENDIF};     { max variables locales par proc }
  MAX_PARAM = {$IFDEF FPC}32{$ELSE}8{$ENDIF};      { max parametres par proc }

Type
  { Un parametre de procedure/fonction }
  TParamRec = Record
    Name    : TString;     { nom du parametre (majuscules)         }
    TypeIdx : Integer;     { index du type dans TypeTab             }
    Offset  : Integer;     { offset dans la pile [EBP+N]           }
    IsVar   : Boolean;     { parametre VAR (par reference) ?       }
    IsConst : Boolean;     { parametre CONST (lecture seule) ?     }
  End;

  { Une variable locale }
  TLocalVar = Record
    Name      : TString;     { nom de la variable (majuscules)      }
    TypeIdx   : Integer;     { index du type dans TypeTab            }
    Offset    : Integer;     { offset dans la pile [EBP-N]          }
    Size      : Integer;     { taille en octets                     }
    IsStatic  : Boolean;     { variable statique (ABSOLUTE) ?       }
    StaticLbl : TString;     { label statique (_TPST_N)             }
    InitVal   : LongInt;     { valeur initiale                      }
    HasInit   : Boolean;     { a une initialisation ?               }
  End;

  { Information sur une procedure/fonction }
  TProcInfo = Record
    Name        : TString;     { nom (majuscules)                     }
    MangledName : TString;     { nom mangled (_TPF_XXX)               }
    IsFunction  : Boolean;     { True = function, False = procedure   }
    RetTypeIdx  : Integer;     { type de retour (-1 si procedure)     }
    ParamCount  : Integer;     { nombre de parametres                 }
    Params      : Array[0..MAX_PARAM - 1] Of TParamRec;
    LocalCount  : Integer;     { nombre de variables locales          }
    Locals      : Array[0..MAX_LOCAL - 1] Of TLocalVar;
    LocalSize   : Integer;     { taille totale du cadre local (octets)}
    BodyStart   : Integer;     { index debut du corps dans TokenPool  }
    BodyEnd     : Integer;     { index fin du corps dans TokenPool    }
    IsForward   : Boolean;     { declaration FORWARD ?                }
    IsExternal  : Boolean;     { declaration EXTERNAL ?               }
    SymIdx      : Integer;     { index dans SymTab                    }
    VarMask     : LongInt;     { bitmask des parametres VAR           }
    RetOffset   : Integer;     { offset de la valeur de retour [EBP] }
  End;

Var
  { Table des procedures/fonctions }
  ProcTab   : Array[0..MAX_PROC - 1] Of TProcInfo;
  ProcCount : Integer;

  { Variables de contexte pour la compilation }
  CurFrameOffset : Integer;   { offset courant dans le cadre local    }
  CurFuncName    : TString;   { nom de la fonction en cours           }
  CurFuncRetOfs  : Integer;   { offset valeur de retour [EBP-N]      }
  CurRetLabel    : TString;   { label de retour de la fonction        }
  CurProcIdx     : Integer;   { index de la proc courante dans ProcTab}

{ ------------------------------------------------------------ }
{ EBPOfs : generer une reference [EBP+N] ou [EBP-N]           }
{ ------------------------------------------------------------ }

Function EBPOfs(Ofs : Integer) : TString;
Begin
  If Ofs >= 0 Then
    EBPOfs := '[EBP+' + IntToStr_(Ofs) + ']'
  Else
    EBPOfs := '[EBP' + IntToStr_(Ofs) + ']';
End;

{ ------------------------------------------------------------ }
{ FindLocal : trouver une variable locale dans la proc courante }
{ Retourne l index dans ProcTab[PI].Locals ou -1               }
{ ------------------------------------------------------------ }

Function FindLocal(PI : Integer; Const Name : TString) : Integer;
Var
  J   : Integer;
  Up  : TString;
Begin
  FindLocal := -1;
  If PI < 0 Then Exit;
  Up := StrUpperCase(Name);
  For J := 0 To ProcTab[PI].LocalCount - 1 Do
    If ProcTab[PI].Locals[J].Name = Up Then
    Begin
      FindLocal := J;
      Exit;
    End;
End;

{ ------------------------------------------------------------ }
{ FindParam : trouver un parametre dans la proc courante       }
{ Retourne l index dans ProcTab[PI].Params ou -1               }
{ ------------------------------------------------------------ }

Function FindParam(PI : Integer; Const Name : TString) : Integer;
Var
  J   : Integer;
  Up  : TString;
Begin
  FindParam := -1;
  If PI < 0 Then Exit;
  Up := StrUpperCase(Name);
  For J := 0 To ProcTab[PI].ParamCount - 1 Do
    If ProcTab[PI].Params[J].Name = Up Then
    Begin
      FindParam := J;
      Exit;
    End;
End;

{ ------------------------------------------------------------ }
{ GenVarRef : generer l operande MASM pour acceder a une       }
{ variable (locale, parametre, globale)                         }
{ Retourne 'DWORD PTR [EBP-N]' ou 'DWORD PTR [_TPV_X]' etc   }
{ ------------------------------------------------------------ }

Function GenVarRef(PI : Integer; Const Name : TString) : TString;
Var
  LI, ParI, SI : Integer;
  Up           : TString;
  Sz           : Integer;
  Pfx          : TString;
Begin
  Up := StrUpperCase(Name);
  GenVarRef := 'DWORD PTR [' + TP_VAR_PFX + Up + ']'; { defaut : globale }

  { Chercher dans les locales }
  LI := FindLocal(PI, Up);
  If LI >= 0 Then
  Begin
    Sz := ProcTab[PI].Locals[LI].Size;
    If Sz = 1 Then
      Pfx := 'BYTE PTR '
    Else
      Pfx := 'DWORD PTR ';
    GenVarRef := Pfx + EBPOfs(ProcTab[PI].Locals[LI].Offset);
    Exit;
  End;

  { Chercher dans les parametres }
  ParI := FindParam(PI, Up);
  If ParI >= 0 Then
  Begin
    GenVarRef := 'DWORD PTR ' + EBPOfs(ProcTab[PI].Params[ParI].Offset);
    Exit;
  End;

  { Chercher dans les symboles globaux }
  SI := SymFind(Up);
  If SI >= 0 Then
  Begin
    If SymTab[SI].Kind = SK_VAR Then
    Begin
      Sz := TypeSizeofIdx(SymTab[SI].TypeIdx);
      If Sz = 1 Then
        Pfx := 'BYTE PTR '
      Else
        Pfx := 'DWORD PTR ';
      GenVarRef := Pfx + '[' + SymTab[SI].MangledName + ']';
    End;
  End;
End;

{ ------------------------------------------------------------ }
{ GenVarAddr : generer l operande MASM pour l adresse d une    }
{ variable (LEA-friendly)                                       }
{ ------------------------------------------------------------ }

Function GenVarAddr(PI : Integer; Const Name : TString) : TString;
Var
  LI, ParI, SI : Integer;
  Up           : TString;
Begin
  Up := StrUpperCase(Name);
  GenVarAddr := TP_VAR_PFX + Up; { defaut : globale }

  LI := FindLocal(PI, Up);
  If LI >= 0 Then
  Begin
    GenVarAddr := EBPOfs(ProcTab[PI].Locals[LI].Offset);
    Exit;
  End;

  ParI := FindParam(PI, Up);
  If ParI >= 0 Then
  Begin
    GenVarAddr := EBPOfs(ProcTab[PI].Params[ParI].Offset);
    Exit;
  End;

  SI := SymFind(Up);
  If SI >= 0 Then
  Begin
    If SymTab[SI].Kind = SK_VAR Then
      GenVarAddr := SymTab[SI].MangledName;
  End;
End;

{ ------------------------------------------------------------ }
{ SkipToMatchingEnd : avancer l index I dans TokenPool          }
{ jusqu au END correspondant au BEGIN courant                   }
{ ------------------------------------------------------------ }

Procedure SkipToMatchingEnd(Var I : Integer);
Var
  Depth : Integer;
  Up    : TString;
Begin
  Depth := 1;
  While (I < TokenCount) And (Depth > 0) Do
  Begin
    If TokenPool[I].Kind = TK_KEYWORD Then
    Begin
      Up := StrUpperCase(TokenPool[I].Val);
      If (Up = 'BEGIN') Or (Up = 'CASE') Or (Up = 'RECORD') Or
         (Up = 'REPEAT') Or (Up = 'ASM') Then
        Inc(Depth)
      Else If Up = 'END' Then
        Dec(Depth);
    End;
    Inc(I);
  End;
End;

{ ------------------------------------------------------------ }
{ ParseProcDecls : scanner le TokenPool pour trouver les       }
{ declarations de PROCEDURE et FUNCTION au niveau global.       }
{ Remplit ProcTab avec les signatures et localise les corps.    }
{ ------------------------------------------------------------ }

Procedure ParseProcDecls;
Var
  I         : Integer;
  Depth     : Integer;
  Up        : TString;
  PI        : Integer;
  PName     : TString;
  IsFunc    : Boolean;
  IsVarP    : Boolean;
  IsConstP  : Boolean;
  GrpStart  : Integer;
  TName     : TString;
  TIdx      : Integer;
  PC        : Integer;  { param count local }
  J         : Integer;
  LocalOfs  : Integer;
  VM        : LongInt;
  SIdx      : Integer;
  RetTIdx   : Integer;
  LTName    : TString;
  LTIdx     : Integer;
  LSz       : Integer;
  LC        : Integer;
  { Variables pour procedures imbriquees (TODO 14) }
  NI        : Integer;
  NIsFunc   : Boolean;
  NName     : TString;
  NPC       : Integer;
  NVM       : LongInt;
  NIsVarP   : Boolean;
  NIsConstP : Boolean;
  NGrpSt    : Integer;
  NTName    : TString;
  NTIdx     : Integer;
  NRetTIdx  : Integer;
  NSIdx     : Integer;
  NLC       : Integer;
  NLocalOfs : Integer;
  NLTName   : TString;
  NLTIdx    : Integer;
  NLSz      : Integer;
  NK        : Integer;
Begin
  ProcCount := 0;
  I := 0;
  Depth := 0;

  While I < TokenCount Do
  Begin
    { Suivre la profondeur BEGIN/END pour rester au niveau global }
    If TokenPool[I].Kind = TK_KEYWORD Then
    Begin
      Up := StrUpperCase(TokenPool[I].Val);

      If (Up = 'BEGIN') Or (Up = 'RECORD') Or (Up = 'REPEAT') Or
         (Up = 'CASE') Or (Up = 'ASM') Then
        Inc(Depth)
      Else If Up = 'END' Then
      Begin
        If Depth > 0 Then
          Dec(Depth);
      End;

      { On ne traite que le niveau global (Depth = 0) }
      If Depth > 0 Then
      Begin
        Inc(I);
        Continue;
      End;

      { === Detecter PROCEDURE ou FUNCTION === }
      If (Up = 'PROCEDURE') Or (Up = 'FUNCTION') Then
      Begin
        If ProcCount >= MAX_PROC Then
        Begin
          Inc(I);
          Continue;
        End;

        IsFunc := (Up = 'FUNCTION');
        Inc(I); { sauter PROCEDURE/FUNCTION }

        { Lire le nom }
        If (I >= TokenCount) Or
           ((TokenPool[I].Kind <> TK_IDENT) And
            (TokenPool[I].Kind <> TK_KEYWORD)) Then
        Begin
          Continue;
        End;
        PName := StrUpperCase(TokenPool[I].Val);
        Inc(I);

        { Verifier si une declaration FORWARD existe deja }
        PI := -1;
        For J := 0 To ProcCount - 1 Do
          If (ProcTab[J].Name = PName) And ProcTab[J].IsForward Then
          Begin
            PI := J;
            Break;
          End;

        If PI < 0 Then
        Begin
          PI := ProcCount;
          ProcTab[PI].Name        := PName;
          ProcTab[PI].MangledName := TP_FUNC_PFX + PName;
          ProcTab[PI].IsFunction  := IsFunc;
          ProcTab[PI].RetTypeIdx  := -1;
          ProcTab[PI].ParamCount  := 0;
          ProcTab[PI].LocalCount  := 0;
          ProcTab[PI].LocalSize   := 0;
          ProcTab[PI].BodyStart   := -1;
          ProcTab[PI].BodyEnd     := -1;
          ProcTab[PI].IsForward   := False;
          ProcTab[PI].IsExternal  := False;
          ProcTab[PI].SymIdx      := -1;
          ProcTab[PI].VarMask     := 0;
          ProcTab[PI].RetOffset   := 0;
        End;

        { Analyser la liste des parametres }
        PC := 0;
        VM := 0;
        If (I < TokenCount) And (TokenPool[I].Kind = TK_PUNCT) And
           (TokenPool[I].Val = '(') Then
        Begin
          Inc(I); { sauter '(' }
          While (I < TokenCount) And
                Not ((TokenPool[I].Kind = TK_PUNCT) And
                     (TokenPool[I].Val = ')')) Do
          Begin
            { Detecter VAR ou CONST }
            IsVarP := False;
            IsConstP := False;
            If (TokenPool[I].Kind = TK_KEYWORD) Then
            Begin
              Up := StrUpperCase(TokenPool[I].Val);
              If Up = 'VAR' Then
              Begin
                IsVarP := True;
                Inc(I);
              End
              Else If Up = 'CONST' Then
              Begin
                IsConstP := True;
                Inc(I);
              End;
            End;

            { Collecter les noms du groupe }
            GrpStart := PC;
            While (I < TokenCount) And
                  ((TokenPool[I].Kind = TK_IDENT) Or
                   (TokenPool[I].Kind = TK_KEYWORD)) Do
            Begin
              If PC < MAX_PARAM Then
              Begin
                ProcTab[PI].Params[PC].Name    := StrUpperCase(TokenPool[I].Val);
                ProcTab[PI].Params[PC].IsVar   := IsVarP;
                ProcTab[PI].Params[PC].IsConst := IsConstP;
                ProcTab[PI].Params[PC].TypeIdx := TY_IDX_INTEGER;
                ProcTab[PI].Params[PC].Offset  := 0;
                If IsVarP Then
                  VM := VM Or (LongInt(1) Shl PC);
                Inc(PC);
              End;
              Inc(I);
              If (I < TokenCount) And (TokenPool[I].Kind = TK_PUNCT) And
                 (TokenPool[I].Val = ',') Then
                Inc(I)
              Else
                Break;
            End;

            { Lire le type ':' TypeName }
            If (I < TokenCount) And (TokenPool[I].Kind = TK_PUNCT) And
               (TokenPool[I].Val = ':') Then
            Begin
              Inc(I);
              If (I < TokenCount) And
                 ((TokenPool[I].Kind = TK_IDENT) Or
                  (TokenPool[I].Kind = TK_KEYWORD)) Then
              Begin
                TName := StrUpperCase(TokenPool[I].Val);
                TIdx := TypeFindByName(TName);
                If TIdx < 0 Then TIdx := TY_IDX_INTEGER;
                For J := GrpStart To PC - 1 Do
                  ProcTab[PI].Params[J].TypeIdx := TIdx;
                Inc(I);
              End;
            End;

            { Sauter ';' entre groupes }
            If (I < TokenCount) And (TokenPool[I].Kind = TK_PUNCT) And
               (TokenPool[I].Val = ';') Then
              Inc(I);
          End;
          { Sauter ')' }
          If (I < TokenCount) And (TokenPool[I].Kind = TK_PUNCT) And
             (TokenPool[I].Val = ')') Then
            Inc(I);
        End;

        ProcTab[PI].ParamCount := PC;
        ProcTab[PI].VarMask    := VM;

        { Calculer les offsets des parametres }
        { Pascal calling convention : params pousses gauche-a-droite }
        { param[0] = [EBP + 8 + (N-1)*4], param[N-1] = [EBP + 8] }
        For J := 0 To PC - 1 Do
          ProcTab[PI].Params[J].Offset := 8 + (PC - 1 - J) * 4;

        { Type de retour pour les fonctions }
        RetTIdx := TY_IDX_INTEGER;
        If IsFunc Then
        Begin
          If (I < TokenCount) And (TokenPool[I].Kind = TK_PUNCT) And
             (TokenPool[I].Val = ':') Then
          Begin
            Inc(I);
            If (I < TokenCount) And
               ((TokenPool[I].Kind = TK_IDENT) Or
                (TokenPool[I].Kind = TK_KEYWORD)) Then
            Begin
              TName := StrUpperCase(TokenPool[I].Val);
              TIdx := TypeFindByName(TName);
              If TIdx >= 0 Then
                RetTIdx := TIdx;
              Inc(I);
            End;
          End;
        End;
        ProcTab[PI].RetTypeIdx := RetTIdx;

        { Attendre ';' apres la signature }
        While (I < TokenCount) And
              Not ((TokenPool[I].Kind = TK_PUNCT) And
                   (TokenPool[I].Val = ';')) Do
          Inc(I);
        If I < TokenCount Then Inc(I);

        { Verifier FORWARD }
        If (I < TokenCount) And
           ((TokenPool[I].Kind = TK_KEYWORD) Or
            (TokenPool[I].Kind = TK_IDENT)) And
           (StrUpperCase(TokenPool[I].Val) = 'FORWARD') Then
        Begin
          ProcTab[PI].IsForward := True;
          Inc(I);
          While (I < TokenCount) And
                Not ((TokenPool[I].Kind = TK_PUNCT) And
                     (TokenPool[I].Val = ';')) Do
            Inc(I);
          If I < TokenCount Then Inc(I);
          { Enregistrer le symbole dans SymTab }
          If IsFunc Then
            SIdx := SymAdd(PName, SK_FUNC, RetTIdx)
          Else
            SIdx := SymAdd(PName, SK_PROC, -1);
          If SIdx >= 0 Then
          Begin
            SymTab[SIdx].ParamCount := PC;
            SymTab[SIdx].IsGlobal   := True;
            SymTab[SIdx].MangledName := TP_FUNC_PFX + PName;
          End;
          ProcTab[PI].SymIdx := SIdx;
          If PI = ProcCount Then
            Inc(ProcCount);
          Continue;
        End;

        { Verifier EXTERNAL }
        If (I < TokenCount) And
           ((TokenPool[I].Kind = TK_KEYWORD) Or
            (TokenPool[I].Kind = TK_IDENT)) And
           (StrUpperCase(TokenPool[I].Val) = 'EXTERNAL') Then
        Begin
          ProcTab[PI].IsExternal := True;
          While (I < TokenCount) And
                Not ((TokenPool[I].Kind = TK_PUNCT) And
                     (TokenPool[I].Val = ';')) Do
            Inc(I);
          If I < TokenCount Then Inc(I);
          If IsFunc Then
            SIdx := SymAdd(PName, SK_FUNC, RetTIdx)
          Else
            SIdx := SymAdd(PName, SK_PROC, -1);
          If SIdx >= 0 Then
          Begin
            SymTab[SIdx].ParamCount  := PC;
            SymTab[SIdx].IsGlobal    := True;
            SymTab[SIdx].IsExternal  := True;
            SymTab[SIdx].MangledName := TP_FUNC_PFX + PName;
          End;
          ProcTab[PI].SymIdx := SIdx;
          If PI = ProcCount Then
            Inc(ProcCount);
          Continue;
        End;

        { Verifier si un corps suit (VAR/CONST/TYPE/LABEL/BEGIN) }
        { Si le prochain token est un mot-cle non lie au corps, ou si }
        { c est PROCEDURE/FUNCTION sans BEGIN avant IMPLEMENTATION,   }
        { traiter comme declaration anticipee (interface de unit)     }
        If (I < TokenCount) And (TokenPool[I].Kind = TK_KEYWORD) Then
        Begin
          Up := StrUpperCase(TokenPool[I].Val);
          If (Up <> 'VAR') And (Up <> 'CONST') And (Up <> 'TYPE') And
             (Up <> 'LABEL') And (Up <> 'BEGIN') And
             (Up <> 'PROCEDURE') And (Up <> 'FUNCTION') Then
          Begin
            { Pas de corps : declaration de type interface/forward implicite }
            ProcTab[PI].IsForward := True;
            If IsFunc Then
              SIdx := SymAdd(PName, SK_FUNC, RetTIdx)
            Else
              SIdx := SymAdd(PName, SK_PROC, -1);
            If SIdx >= 0 Then
            Begin
              SymTab[SIdx].ParamCount  := PC;
              SymTab[SIdx].IsGlobal    := True;
              SymTab[SIdx].MangledName := TP_FUNC_PFX + PName;
            End;
            ProcTab[PI].SymIdx := SIdx;
            If PI = ProcCount Then
              Inc(ProcCount);
            Continue;
          End;
          { Si PROCEDURE/FUNCTION suit immediatement, scanner en avant }
          { pour detecter si un BEGIN existe avant IMPLEMENTATION/END  }
          If (Up = 'PROCEDURE') Or (Up = 'FUNCTION') Then
          Begin
            J := I;
            SIdx := -1;  { reutiliser SIdx comme flag HasBody }
            While (J < TokenCount) Do
            Begin
              If TokenPool[J].Kind = TK_KEYWORD Then
              Begin
                Up := StrUpperCase(TokenPool[J].Val);
                If Up = 'BEGIN' Then
                Begin SIdx := 1; Break; End;
                If (Up = 'IMPLEMENTATION') Or (Up = 'INTERFACE') Then
                  Break;
              End;
              Inc(J);
            End;
            If SIdx < 0 Then
            Begin
              { Pas de BEGIN trouve : section interface, forward implicite }
              ProcTab[PI].IsForward := True;
              If IsFunc Then
                SIdx := SymAdd(PName, SK_FUNC, RetTIdx)
              Else
                SIdx := SymAdd(PName, SK_PROC, -1);
              If SIdx >= 0 Then
              Begin
                SymTab[SIdx].ParamCount  := PC;
                SymTab[SIdx].IsGlobal    := True;
                SymTab[SIdx].MangledName := TP_FUNC_PFX + PName;
              End;
              ProcTab[PI].SymIdx := SIdx;
              If PI = ProcCount Then
                Inc(ProcCount);
              Continue;
            End;
          End;
        End;

        { Reserver le slot dans ProcTab pour la proc courante }
        { AVANT de scanner les sections locales qui peuvent creer }
        { des procs imbriquees (TODO 14)                          }
        If PI = ProcCount Then
          Inc(ProcCount);

        LocalOfs := 0;
        LC := 0;

        { Reserver l emplacement de la valeur de retour pour les fonctions }
        If IsFunc Then
        Begin
          LocalOfs := LocalOfs + 4;
          ProcTab[PI].RetOffset := -LocalOfs;
        End;

        { Scanner les sections locales VAR/CONST/TYPE avant BEGIN }
        While (I < TokenCount) Do
        Begin
          If TokenPool[I].Kind <> TK_KEYWORD Then Break;
          Up := StrUpperCase(TokenPool[I].Val);

          If Up = 'VAR' Then
          Begin
            Inc(I); { sauter VAR }
            { Parser les declarations de variables locales }
            While (I < TokenCount) Do
            Begin
              If (TokenPool[I].Kind = TK_KEYWORD) Then
              Begin
                Up := StrUpperCase(TokenPool[I].Val);
                If (Up = 'VAR') Or (Up = 'CONST') Or (Up = 'TYPE') Or
                   (Up = 'BEGIN') Or (Up = 'PROCEDURE') Or
                   (Up = 'FUNCTION') Or (Up = 'LABEL') Then
                  Break;
              End;

              If (TokenPool[I].Kind <> TK_IDENT) And
                 (TokenPool[I].Kind <> TK_KEYWORD) Then
              Begin
                Inc(I);
                Continue;
              End;

              { Collecter les noms }
              GrpStart := LC;
              While (I < TokenCount) And
                    ((TokenPool[I].Kind = TK_IDENT) Or
                     (TokenPool[I].Kind = TK_KEYWORD)) Do
              Begin
                If LC < MAX_LOCAL Then
                Begin
                  ProcTab[PI].Locals[LC].Name    := StrUpperCase(TokenPool[I].Val);
                  ProcTab[PI].Locals[LC].TypeIdx  := TY_IDX_INTEGER;
                  ProcTab[PI].Locals[LC].Size     := 4;
                  ProcTab[PI].Locals[LC].IsStatic := False;
                  ProcTab[PI].Locals[LC].StaticLbl:= '';
                  ProcTab[PI].Locals[LC].InitVal  := 0;
                  ProcTab[PI].Locals[LC].HasInit  := False;
                  Inc(LC);
                End;
                Inc(I);
                If (I < TokenCount) And (TokenPool[I].Kind = TK_PUNCT)
                   And (TokenPool[I].Val = ',') Then
                  Inc(I)
                Else
                  Break;
              End;

              { Lire ':' TypeName }
              If (I < TokenCount) And (TokenPool[I].Kind = TK_PUNCT) And
                 (TokenPool[I].Val = ':') Then
              Begin
                Inc(I);
                LTName := '';
                If (I < TokenCount) And
                   ((TokenPool[I].Kind = TK_IDENT) Or
                    (TokenPool[I].Kind = TK_KEYWORD)) Then
                Begin
                  LTName := StrUpperCase(TokenPool[I].Val);
                  Inc(I);
                End;

                LTIdx := TypeFindByName(LTName);
                If LTIdx < 0 Then LTIdx := TY_IDX_INTEGER;
                LSz := TypeSizeofIdx(LTIdx);
                If LSz < 4 Then LSz := 4;  { min 4 bytes alignment }

                For J := GrpStart To LC - 1 Do
                Begin
                  ProcTab[PI].Locals[J].TypeIdx := LTIdx;
                  ProcTab[PI].Locals[J].Size    := LSz;
                  LocalOfs := LocalOfs + LSz;
                  { Aligner sur 4 octets }
                  If (LocalOfs And 3) <> 0 Then
                    LocalOfs := (LocalOfs + 3) And (Not 3);
                  ProcTab[PI].Locals[J].Offset := -LocalOfs;
                End;
              End;

              { Avancer au ';' }
              While (I < TokenCount) And
                    Not ((TokenPool[I].Kind = TK_PUNCT) And
                         (TokenPool[I].Val = ';')) Do
                Inc(I);
              If I < TokenCount Then Inc(I);
            End;
          End
          Else If (Up = 'CONST') Or (Up = 'TYPE') Or (Up = 'LABEL') Then
          Begin
            { Sauter les sections CONST/TYPE/LABEL locales }
            Inc(I);
            While (I < TokenCount) Do
            Begin
              If (TokenPool[I].Kind = TK_KEYWORD) Then
              Begin
                Up := StrUpperCase(TokenPool[I].Val);
                If (Up = 'VAR') Or (Up = 'CONST') Or (Up = 'TYPE') Or
                   (Up = 'BEGIN') Or (Up = 'PROCEDURE') Or
                   (Up = 'FUNCTION') Or (Up = 'LABEL') Then
                  Break;
              End;
              Inc(I);
            End;
          End
          Else If (Up = 'PROCEDURE') Or (Up = 'FUNCTION') Then
          Begin
            { Parser les procedures/fonctions imbriquees (TODO 14) }
            { Elles deviennent des entrees separees dans ProcTab }
            If ProcCount < MAX_PROC Then
            Begin
              NIsFunc := (Up = 'FUNCTION');
                Inc(I); { sauter PROCEDURE/FUNCTION }

                { Lire le nom }
                If (I < TokenCount) And
                   ((TokenPool[I].Kind = TK_IDENT) Or
                    (TokenPool[I].Kind = TK_KEYWORD)) Then
                Begin
                  NName := StrUpperCase(TokenPool[I].Val);
                  Inc(I);
                End
                Else
                  NName := '';

                NI := ProcCount;
                ProcTab[NI].Name        := NName;
                ProcTab[NI].MangledName := TP_FUNC_PFX + NName;
                ProcTab[NI].IsFunction  := NIsFunc;
                ProcTab[NI].RetTypeIdx  := -1;
                ProcTab[NI].ParamCount  := 0;
                ProcTab[NI].LocalCount  := 0;
                ProcTab[NI].LocalSize   := 0;
                ProcTab[NI].BodyStart   := -1;
                ProcTab[NI].BodyEnd     := -1;
                ProcTab[NI].IsForward   := False;
                ProcTab[NI].IsExternal  := False;
                ProcTab[NI].SymIdx      := -1;
                ProcTab[NI].VarMask     := 0;
                ProcTab[NI].RetOffset   := 0;

                { Parser les parametres }
                NPC := 0;
                NVM := 0;
                If (I < TokenCount) And (TokenPool[I].Kind = TK_PUNCT) And
                   (TokenPool[I].Val = '(') Then
                Begin
                  Inc(I);
                  While (I < TokenCount) And
                        Not ((TokenPool[I].Kind = TK_PUNCT) And
                             (TokenPool[I].Val = ')')) Do
                  Begin
                    NIsVarP := False;
                    NIsConstP := False;
                    If (TokenPool[I].Kind = TK_KEYWORD) Then
                    Begin
                      If StrUpperCase(TokenPool[I].Val) = 'VAR' Then
                      Begin NIsVarP := True; Inc(I); End
                      Else If StrUpperCase(TokenPool[I].Val) = 'CONST' Then
                      Begin NIsConstP := True; Inc(I); End;
                    End;
                    NGrpSt := NPC;
                    While (I < TokenCount) And
                          ((TokenPool[I].Kind = TK_IDENT) Or
                           (TokenPool[I].Kind = TK_KEYWORD)) Do
                    Begin
                      If NPC < MAX_PARAM Then
                      Begin
                        ProcTab[NI].Params[NPC].Name    := StrUpperCase(TokenPool[I].Val);
                        ProcTab[NI].Params[NPC].IsVar   := NIsVarP;
                        ProcTab[NI].Params[NPC].IsConst := NIsConstP;
                        ProcTab[NI].Params[NPC].TypeIdx := TY_IDX_INTEGER;
                        ProcTab[NI].Params[NPC].Offset  := 0;
                        If NIsVarP Then
                          NVM := NVM Or (LongInt(1) Shl NPC);
                        Inc(NPC);
                      End;
                      Inc(I);
                      If (I < TokenCount) And (TokenPool[I].Kind = TK_PUNCT) And
                         (TokenPool[I].Val = ',') Then Inc(I) Else Break;
                    End;
                    If (I < TokenCount) And (TokenPool[I].Kind = TK_PUNCT) And
                       (TokenPool[I].Val = ':') Then
                    Begin
                      Inc(I);
                      If (I < TokenCount) And
                         ((TokenPool[I].Kind = TK_IDENT) Or
                          (TokenPool[I].Kind = TK_KEYWORD)) Then
                      Begin
                        NTName := StrUpperCase(TokenPool[I].Val);
                        NTIdx := TypeFindByName(NTName);
                        If NTIdx < 0 Then NTIdx := TY_IDX_INTEGER;
                        For NK := NGrpSt To NPC - 1 Do
                          ProcTab[NI].Params[NK].TypeIdx := NTIdx;
                        Inc(I);
                      End;
                    End;
                    If (I < TokenCount) And (TokenPool[I].Kind = TK_PUNCT) And
                       (TokenPool[I].Val = ';') Then Inc(I);
                  End;
                  If (I < TokenCount) And (TokenPool[I].Kind = TK_PUNCT) And
                     (TokenPool[I].Val = ')') Then Inc(I);
                End;
                ProcTab[NI].ParamCount := NPC;
                ProcTab[NI].VarMask    := NVM;
                For NK := 0 To NPC - 1 Do
                  ProcTab[NI].Params[NK].Offset := 8 + (NPC - 1 - NK) * 4;

                { Type de retour }
                NRetTIdx := TY_IDX_INTEGER;
                If NIsFunc Then
                Begin
                  If (I < TokenCount) And (TokenPool[I].Kind = TK_PUNCT) And
                     (TokenPool[I].Val = ':') Then
                  Begin
                    Inc(I);
                    If (I < TokenCount) And
                       ((TokenPool[I].Kind = TK_IDENT) Or
                        (TokenPool[I].Kind = TK_KEYWORD)) Then
                    Begin
                      NTName := StrUpperCase(TokenPool[I].Val);
                      NTIdx := TypeFindByName(NTName);
                      If NTIdx >= 0 Then NRetTIdx := NTIdx;
                      Inc(I);
                    End;
                  End;
                End;
                ProcTab[NI].RetTypeIdx := NRetTIdx;

                { Attendre ';' apres la signature }
                While (I < TokenCount) And
                      Not ((TokenPool[I].Kind = TK_PUNCT) And
                           (TokenPool[I].Val = ';')) Do
                  Inc(I);
                If I < TokenCount Then Inc(I);

                { Verifier FORWARD }
                If (I < TokenCount) And
                   ((TokenPool[I].Kind = TK_KEYWORD) Or
                    (TokenPool[I].Kind = TK_IDENT)) And
                   (StrUpperCase(TokenPool[I].Val) = 'FORWARD') Then
                Begin
                  ProcTab[NI].IsForward := True;
                  While (I < TokenCount) And
                        Not ((TokenPool[I].Kind = TK_PUNCT) And
                             (TokenPool[I].Val = ';')) Do
                    Inc(I);
                  If I < TokenCount Then Inc(I);
                End
                Else If (I < TokenCount) And
                        (TokenPool[I].Kind = TK_KEYWORD) And
                        (StrUpperCase(TokenPool[I].Val) <> 'VAR') And
                        (StrUpperCase(TokenPool[I].Val) <> 'CONST') And
                        (StrUpperCase(TokenPool[I].Val) <> 'TYPE') And
                        (StrUpperCase(TokenPool[I].Val) <> 'LABEL') And
                        (StrUpperCase(TokenPool[I].Val) <> 'BEGIN') And
                        (StrUpperCase(TokenPool[I].Val) <> 'PROCEDURE') And
                        (StrUpperCase(TokenPool[I].Val) <> 'FUNCTION') Then
                Begin
                  { Pas de corps : declaration de type interface/forward implicite }
                  ProcTab[NI].IsForward := True;
                End
                Else
                Begin
                  { Scanner les variables locales de la proc imbriquee }
                  NLocalOfs := 0;
                  NLC := 0;
                  If NIsFunc Then
                  Begin
                    NLocalOfs := NLocalOfs + 4;
                    ProcTab[NI].RetOffset := -NLocalOfs;
                  End;
                  While (I < TokenCount) Do
                  Begin
                    If TokenPool[I].Kind <> TK_KEYWORD Then Break;
                    Up := StrUpperCase(TokenPool[I].Val);
                    If Up = 'VAR' Then
                    Begin
                      Inc(I);
                      While (I < TokenCount) Do
                      Begin
                        If (TokenPool[I].Kind = TK_KEYWORD) Then
                        Begin
                          Up := StrUpperCase(TokenPool[I].Val);
                          If (Up = 'VAR') Or (Up = 'CONST') Or (Up = 'TYPE') Or
                             (Up = 'BEGIN') Or (Up = 'PROCEDURE') Or
                             (Up = 'FUNCTION') Or (Up = 'LABEL') Then
                            Break;
                        End;
                        If (TokenPool[I].Kind <> TK_IDENT) And
                           (TokenPool[I].Kind <> TK_KEYWORD) Then
                        Begin Inc(I); Continue; End;
                        NGrpSt := NLC;
                        While (I < TokenCount) And
                              ((TokenPool[I].Kind = TK_IDENT) Or
                               (TokenPool[I].Kind = TK_KEYWORD)) Do
                        Begin
                          If NLC < MAX_LOCAL Then
                          Begin
                            ProcTab[NI].Locals[NLC].Name    := StrUpperCase(TokenPool[I].Val);
                            ProcTab[NI].Locals[NLC].TypeIdx  := TY_IDX_INTEGER;
                            ProcTab[NI].Locals[NLC].Size     := 4;
                            ProcTab[NI].Locals[NLC].IsStatic := False;
                            ProcTab[NI].Locals[NLC].StaticLbl:= '';
                            ProcTab[NI].Locals[NLC].InitVal  := 0;
                            ProcTab[NI].Locals[NLC].HasInit  := False;
                            Inc(NLC);
                          End;
                          Inc(I);
                          If (I < TokenCount) And (TokenPool[I].Kind = TK_PUNCT)
                             And (TokenPool[I].Val = ',') Then Inc(I) Else Break;
                        End;
                        If (I < TokenCount) And (TokenPool[I].Kind = TK_PUNCT) And
                           (TokenPool[I].Val = ':') Then
                        Begin
                          Inc(I);
                          NLTName := '';
                          If (I < TokenCount) And
                             ((TokenPool[I].Kind = TK_IDENT) Or
                              (TokenPool[I].Kind = TK_KEYWORD)) Then
                          Begin
                            NLTName := StrUpperCase(TokenPool[I].Val);
                            Inc(I);
                          End;
                          NLTIdx := TypeFindByName(NLTName);
                          If NLTIdx < 0 Then NLTIdx := TY_IDX_INTEGER;
                          NLSz := TypeSizeofIdx(NLTIdx);
                          If NLSz < 4 Then NLSz := 4;
                          For NK := NGrpSt To NLC - 1 Do
                          Begin
                            ProcTab[NI].Locals[NK].TypeIdx := NLTIdx;
                            ProcTab[NI].Locals[NK].Size    := NLSz;
                            NLocalOfs := NLocalOfs + NLSz;
                            If (NLocalOfs And 3) <> 0 Then
                              NLocalOfs := (NLocalOfs + 3) And (Not 3);
                            ProcTab[NI].Locals[NK].Offset := -NLocalOfs;
                          End;
                        End;
                        While (I < TokenCount) And
                              Not ((TokenPool[I].Kind = TK_PUNCT) And
                                   (TokenPool[I].Val = ';')) Do
                          Inc(I);
                        If I < TokenCount Then Inc(I);
                      End;
                    End
                    Else If (Up = 'CONST') Or (Up = 'TYPE') Or (Up = 'LABEL') Then
                    Begin
                      Inc(I);
                      While (I < TokenCount) Do
                      Begin
                        If (TokenPool[I].Kind = TK_KEYWORD) Then
                        Begin
                          Up := StrUpperCase(TokenPool[I].Val);
                          If (Up = 'VAR') Or (Up = 'CONST') Or (Up = 'TYPE') Or
                             (Up = 'BEGIN') Or (Up = 'PROCEDURE') Or
                             (Up = 'FUNCTION') Or (Up = 'LABEL') Then
                            Break;
                        End;
                        Inc(I);
                      End;
                    End
                    Else
                      Break;
                  End;
                  ProcTab[NI].LocalCount := NLC;
                  ProcTab[NI].LocalSize  := NLocalOfs;

                  { Localiser le corps (BEGIN ... END) }
                  If (I < TokenCount) And (TokenPool[I].Kind = TK_KEYWORD) And
                     (StrUpperCase(TokenPool[I].Val) = 'BEGIN') Then
                  Begin
                    ProcTab[NI].BodyStart := I;
                    Inc(I);
                    SkipToMatchingEnd(I);
                    ProcTab[NI].BodyEnd := I - 1;
                  End;
                  { Sauter le ';' apres END }
                  If (I < TokenCount) And (TokenPool[I].Kind = TK_PUNCT) And
                     (TokenPool[I].Val = ';') Then
                    Inc(I);
                End;

                { Enregistrer le symbole dans SymTab }
                If NIsFunc Then
                  NSIdx := SymAdd(NName, SK_FUNC, NRetTIdx)
                Else
                  NSIdx := SymAdd(NName, SK_PROC, -1);
                If NSIdx >= 0 Then
                Begin
                  SymTab[NSIdx].ParamCount  := NPC;
                  SymTab[NSIdx].IsGlobal    := True;
                  SymTab[NSIdx].MangledName := TP_FUNC_PFX + NName;
                End;
                ProcTab[NI].SymIdx := NSIdx;
                Inc(ProcCount);
            End
            Else
            Begin
              { Pas de place dans ProcTab : sauter }
              Inc(I);
              While (I < TokenCount) Do
              Begin
                If (TokenPool[I].Kind = TK_KEYWORD) And
                   (StrUpperCase(TokenPool[I].Val) = 'BEGIN') Then
                Begin
                  Inc(I);
                  SkipToMatchingEnd(I);
                  Break;
                End;
                Inc(I);
              End;
              If (I < TokenCount) And (TokenPool[I].Kind = TK_PUNCT) And
                 (TokenPool[I].Val = ';') Then
                Inc(I);
            End;
          End
          Else
            Break;
        End;

        ProcTab[PI].LocalCount := LC;
        ProcTab[PI].LocalSize  := LocalOfs;

        { Localiser le corps (BEGIN ... END) }
        If (I < TokenCount) And (TokenPool[I].Kind = TK_KEYWORD) And
           (StrUpperCase(TokenPool[I].Val) = 'BEGIN') Then
        Begin
          ProcTab[PI].BodyStart := I;
          Inc(I); { sauter BEGIN }
          SkipToMatchingEnd(I);
          ProcTab[PI].BodyEnd := I - 1;
        End;

        { Sauter le ';' apres END }
        If (I < TokenCount) And (TokenPool[I].Kind = TK_PUNCT) And
           (TokenPool[I].Val = ';') Then
          Inc(I);

        { Enregistrer le symbole dans SymTab (si pas deja fait via FORWARD) }
        If ProcTab[PI].IsForward Then
        Begin
          { Resoudre la declaration FORWARD }
          ProcTab[PI].IsForward := False;
        End
        Else
        Begin
          If IsFunc Then
            SIdx := SymAdd(PName, SK_FUNC, RetTIdx)
          Else
            SIdx := SymAdd(PName, SK_PROC, -1);
          If SIdx >= 0 Then
          Begin
            SymTab[SIdx].ParamCount  := PC;
            SymTab[SIdx].IsGlobal    := True;
            SymTab[SIdx].MangledName := TP_FUNC_PFX + PName;
          End;
          ProcTab[PI].SymIdx := SIdx;
        End;
        If PI = ProcCount Then
          Inc(ProcCount);
        Continue;
      End;

    End; { if keyword }

    Inc(I);
  End; { while }
End;


{ ============================================================ }
{ TODO 15 - TABLEAUX, RECORDS, ENSEMBLES ET OBJETS [IMPLEMENTE] }
{ ============================================================ }

{ ------------------------------------------------------------ }
{ ParseTypeDecls : scanner le TokenPool pour traiter les        }
{ sections TYPE au niveau global.                               }
{ Gere ARRAY, RECORD, SET, OBJECT, enums, alias, subrange.     }
{ ------------------------------------------------------------ }

Procedure ParseTypeDecls;
Var
  I       : Integer;
  Depth   : Integer;
  Up      : TString;
  TName   : TString;
  TIdx    : Integer;
  SIdx    : Integer;
  FName   : TString;
  FTName  : TString;
  FTIdx   : Integer;
  FOfs    : Integer;
  FSz     : Integer;
  FC      : Integer;
  ArrLo   : LongInt;
  ArrHi   : LongInt;
  ArrElem : LongInt;
  ElemType: TString;
  ElemSz  : Integer;
  BaseTN  : TString;
  BTIdx   : Integer;
  ObjPar  : TString;
Begin
  I := 0;
  Depth := 0;

  While I < TokenCount Do
  Begin
    If (TokenPool[I].Kind = TK_KEYWORD) Then
    Begin
      Up := StrUpperCase(TokenPool[I].Val);

      If (Up = 'BEGIN') Or (Up = 'RECORD') Or (Up = 'OBJECT') Or
         (Up = 'REPEAT') Or (Up = 'ASM') Then
      Begin
        Inc(Depth);
        Inc(I);
        Continue;
      End;

      If Up = 'END' Then
      Begin
        If Depth > 0 Then Dec(Depth);
        Inc(I);
        Continue;
      End;

      If Up = 'UNTIL' Then
      Begin
        If Depth > 0 Then Dec(Depth);
        Inc(I);
        Continue;
      End;

      If Depth > 0 Then
      Begin
        Inc(I);
        Continue;
      End;

      { --- Section TYPE --- }
      If Up = 'TYPE' Then
      Begin
        Inc(I);

        While I < TokenCount Do
        Begin
          { Si on rencontre un mot-cle de section, sortir }
          If (TokenPool[I].Kind = TK_KEYWORD) Then
          Begin
            Up := StrUpperCase(TokenPool[I].Val);
            If (Up = 'VAR') Or (Up = 'CONST') Or (Up = 'TYPE') Or
               (Up = 'PROCEDURE') Or (Up = 'FUNCTION') Or
               (Up = 'BEGIN') Or (Up = 'LABEL') Or
               (Up = 'USES') Or (Up = 'PROGRAM') Then
              Break;
          End;

          { Lire le nom du type }
          If (TokenPool[I].Kind <> TK_IDENT) Then
          Begin
            Inc(I);
            Continue;
          End;
          TName := StrUpperCase(TokenPool[I].Val);
          Inc(I);

          { Attendre '=' }
          If (I < TokenCount) And (TokenPool[I].Kind = TK_OP) And
             (TokenPool[I].Val = '=') Then
            Inc(I)
          Else
          Begin
            While (I < TokenCount) And
                  Not ((TokenPool[I].Kind = TK_PUNCT) And
                       (TokenPool[I].Val = ';')) Do
              Inc(I);
            If I < TokenCount Then Inc(I);
            Continue;
          End;

          { --- PACKED prefix --- }
          If (I < TokenCount) And (TokenPool[I].Kind = TK_KEYWORD) And
             (StrUpperCase(TokenPool[I].Val) = 'PACKED') Then
            Inc(I);

          If I >= TokenCount Then Break;
          Up := StrUpperCase(TokenPool[I].Val);

          { --- ARRAY [lo..hi] OF T --- }
          If (TokenPool[I].Kind = TK_KEYWORD) And (Up = 'ARRAY') Then
          Begin
            Inc(I);
            ArrLo := 0;
            ArrHi := 0;
            ElemType := 'INTEGER';

            If (I < TokenCount) And (TokenPool[I].Kind = TK_PUNCT) And
               (TokenPool[I].Val = '[') Then
            Begin
              Inc(I);
              If (I < TokenCount) And (TokenPool[I].Kind = TK_INTEGER) Then
              Begin
                ArrLo := TokenPool[I].IntVal;
                Inc(I);
              End;
              If (I < TokenCount) And (TokenPool[I].Kind = TK_PUNCT) And
                 (TokenPool[I].Val = '..') Then
                Inc(I);
              If (I < TokenCount) And (TokenPool[I].Kind = TK_INTEGER) Then
              Begin
                ArrHi := TokenPool[I].IntVal;
                Inc(I);
              End;
              If (I < TokenCount) And (TokenPool[I].Kind = TK_PUNCT) And
                 (TokenPool[I].Val = ']') Then
                Inc(I);
            End;

            If (I < TokenCount) And (TokenPool[I].Kind = TK_KEYWORD) And
               (StrUpperCase(TokenPool[I].Val) = 'OF') Then
              Inc(I);

            If (I < TokenCount) And
               ((TokenPool[I].Kind = TK_IDENT) Or
                (TokenPool[I].Kind = TK_KEYWORD)) Then
            Begin
              ElemType := StrUpperCase(TokenPool[I].Val);
              Inc(I);
            End;

            ArrElem := ArrHi - ArrLo + 1;
            If ArrElem < 1 Then ArrElem := 1;
            ElemSz := TPTypeSizeof(ElemType);
            If ElemSz < 0 Then
            Begin
              BTIdx := TypeFindByName(ElemType);
              If BTIdx >= 0 Then
                ElemSz := TypeTab[BTIdx].Size
              Else
                ElemSz := 4;
            End;

            TIdx := TypeAdd(TYK_ARRAY, TName, ArrElem * ElemSz, 4, False, -1);
            If TIdx >= 0 Then
            Begin
              TypeTab[TIdx].Lo := ArrLo;
              TypeTab[TIdx].Hi := ArrHi;
              BTIdx := TypeFindByName(ElemType);
              If BTIdx < 0 Then BTIdx := TY_IDX_INTEGER;
              TypeTab[TIdx].BaseTypeIdx := BTIdx;
            End;
            SIdx := SymAdd(TName, SK_TYPE, TIdx);

            While (I < TokenCount) And
                  Not ((TokenPool[I].Kind = TK_PUNCT) And
                       (TokenPool[I].Val = ';')) Do
              Inc(I);
            If I < TokenCount Then Inc(I);
            Continue;
          End;

          { --- RECORD ... END --- }
          If (TokenPool[I].Kind = TK_KEYWORD) And (Up = 'RECORD') Then
          Begin
            Inc(I);
            FC := 0;
            FOfs := 0;

            TIdx := TypeAdd(TYK_RECORD, TName, 0, 4, False, -1);

            While I < TokenCount Do
            Begin
              If (TokenPool[I].Kind = TK_KEYWORD) And
                 (StrUpperCase(TokenPool[I].Val) = 'END') Then
              Begin
                Inc(I);
                Break;
              End;
              If (TokenPool[I].Kind = TK_KEYWORD) And
                 (StrUpperCase(TokenPool[I].Val) = 'CASE') Then
              Begin
                { Variant record: skip to END }
                While (I < TokenCount) And
                      Not ((TokenPool[I].Kind = TK_KEYWORD) And
                           (StrUpperCase(TokenPool[I].Val) = 'END')) Do
                  Inc(I);
                Continue;
              End;

              { Lire le(s) nom(s) de champ }
              If (TokenPool[I].Kind <> TK_IDENT) Then
              Begin
                Inc(I);
                Continue;
              End;
              FName := StrUpperCase(TokenPool[I].Val);
              Inc(I);

              { Attendre ':' }
              If (I < TokenCount) And (TokenPool[I].Kind = TK_PUNCT) And
                 (TokenPool[I].Val = ':') Then
                Inc(I)
              Else
              Begin
                While (I < TokenCount) And
                      Not ((TokenPool[I].Kind = TK_PUNCT) And
                           ((TokenPool[I].Val = ';') Or (TokenPool[I].Val = ')'))) And
                      Not ((TokenPool[I].Kind = TK_KEYWORD) And
                           (StrUpperCase(TokenPool[I].Val) = 'END')) Do
                  Inc(I);
                If (I < TokenCount) And (TokenPool[I].Kind = TK_PUNCT) And
                   (TokenPool[I].Val = ';') Then Inc(I);
                Continue;
              End;

              { Lire le type du champ }
              FTName := 'INTEGER';
              If (I < TokenCount) And
                 ((TokenPool[I].Kind = TK_IDENT) Or
                  (TokenPool[I].Kind = TK_KEYWORD)) Then
              Begin
                FTName := StrUpperCase(TokenPool[I].Val);
                Inc(I);
              End;

              FSz := TPTypeSizeof(FTName);
              If FSz < 0 Then
              Begin
                FTIdx := TypeFindByName(FTName);
                If FTIdx >= 0 Then
                  FSz := TypeTab[FTIdx].Size
                Else
                  FSz := 4;
              End;
              FTIdx := TypeFindByName(FTName);
              If FTIdx < 0 Then FTIdx := TY_IDX_INTEGER;

              { Enregistrer le champ }
              If (TIdx >= 0) And (FC < MAX_FIELDS) Then
              Begin
                TypeTab[TIdx].Fields[FC].Name    := FName;
                TypeTab[TIdx].Fields[FC].TypeIdx := FTIdx;
                TypeTab[TIdx].Fields[FC].Offset  := FOfs;
                Inc(FC);
                TypeTab[TIdx].FieldCount := FC;
                FOfs := FOfs + FSz;
                TypeTab[TIdx].Size := FOfs;
              End;

              { Passer le ';' entre champs }
              If (I < TokenCount) And (TokenPool[I].Kind = TK_PUNCT) And
                 (TokenPool[I].Val = ';') Then
                Inc(I);
            End;

            SIdx := SymAdd(TName, SK_TYPE, TIdx);

            { Passer le ';' apres END }
            If (I < TokenCount) And (TokenPool[I].Kind = TK_PUNCT) And
               (TokenPool[I].Val = ';') Then
              Inc(I);
            Continue;
          End;

          { --- SET OF T --- }
          If (TokenPool[I].Kind = TK_KEYWORD) And (Up = 'SET') Then
          Begin
            Inc(I);
            If (I < TokenCount) And (TokenPool[I].Kind = TK_KEYWORD) And
               (StrUpperCase(TokenPool[I].Val) = 'OF') Then
              Inc(I);

            BaseTN := 'BYTE';
            If (I < TokenCount) And
               ((TokenPool[I].Kind = TK_IDENT) Or
                (TokenPool[I].Kind = TK_KEYWORD)) Then
            Begin
              BaseTN := StrUpperCase(TokenPool[I].Val);
              Inc(I);
            End;
            BTIdx := TypeFindByName(BaseTN);
            If BTIdx < 0 Then BTIdx := TY_IDX_BYTE;

            TIdx := TypeAdd(TYK_SET, TName, 32, 4, False, BTIdx);
            SIdx := SymAdd(TName, SK_TYPE, TIdx);

            While (I < TokenCount) And
                  Not ((TokenPool[I].Kind = TK_PUNCT) And
                       (TokenPool[I].Val = ';')) Do
              Inc(I);
            If I < TokenCount Then Inc(I);
            Continue;
          End;

          { --- OBJECT ... END --- }
          If (TokenPool[I].Kind = TK_KEYWORD) And (Up = 'OBJECT') Then
          Begin
            Inc(I);
            FC := 0;
            FOfs := 0;
            ObjPar := '';

            { Heritage : OBJECT(Parent) }
            If (I < TokenCount) And (TokenPool[I].Kind = TK_PUNCT) And
               (TokenPool[I].Val = '(') Then
            Begin
              Inc(I);
              If (I < TokenCount) And
                 ((TokenPool[I].Kind = TK_IDENT) Or
                  (TokenPool[I].Kind = TK_KEYWORD)) Then
              Begin
                ObjPar := StrUpperCase(TokenPool[I].Val);
                Inc(I);
              End;
              If (I < TokenCount) And (TokenPool[I].Kind = TK_PUNCT) And
                 (TokenPool[I].Val = ')') Then
                Inc(I);

              { Copier les champs du parent }
              BTIdx := TypeFindByName(ObjPar);
              If (BTIdx >= 0) And (TypeTab[BTIdx].Kind = TYK_OBJECT) Then
              Begin
                FC := TypeTab[BTIdx].FieldCount;
                FOfs := TypeTab[BTIdx].Size;
              End;
            End;

            TIdx := TypeAdd(TYK_OBJECT, TName, 0, 4, False, -1);

            { Copier champs du parent si heritage }
            If (ObjPar <> '') And (BTIdx >= 0) Then
            Begin
              If TIdx >= 0 Then
              Begin
                TypeTab[TIdx].BaseTypeIdx := BTIdx;
                For SIdx := 0 To TypeTab[BTIdx].FieldCount - 1 Do
                Begin
                  If FC < MAX_FIELDS Then
                  Begin
                    TypeTab[TIdx].Fields[SIdx] := TypeTab[BTIdx].Fields[SIdx];
                  End;
                End;
                TypeTab[TIdx].FieldCount := FC;
                TypeTab[TIdx].Size := FOfs;
              End;
            End;

            { Parser les champs et methodes }
            While I < TokenCount Do
            Begin
              If (TokenPool[I].Kind = TK_KEYWORD) And
                 (StrUpperCase(TokenPool[I].Val) = 'END') Then
              Begin
                Inc(I);
                Break;
              End;

              { Skip CONSTRUCTOR, DESTRUCTOR, PROCEDURE, FUNCTION }
              Up := '';
              If TokenPool[I].Kind = TK_KEYWORD Then
                Up := StrUpperCase(TokenPool[I].Val);
              If (Up = 'CONSTRUCTOR') Or (Up = 'DESTRUCTOR') Or
                 (Up = 'PROCEDURE') Or (Up = 'FUNCTION') Or
                 (Up = 'VIRTUAL') Or (Up = 'PRIVATE') Or
                 (Up = 'PUBLIC') Then
              Begin
                While (I < TokenCount) And
                      Not ((TokenPool[I].Kind = TK_PUNCT) And
                           (TokenPool[I].Val = ';')) And
                      Not ((TokenPool[I].Kind = TK_KEYWORD) And
                           (StrUpperCase(TokenPool[I].Val) = 'END')) Do
                  Inc(I);
                If (I < TokenCount) And (TokenPool[I].Kind = TK_PUNCT) And
                   (TokenPool[I].Val = ';') Then
                  Inc(I);
                Continue;
              End;

              { Champ de l objet }
              If (TokenPool[I].Kind <> TK_IDENT) Then
              Begin
                Inc(I);
                Continue;
              End;
              FName := StrUpperCase(TokenPool[I].Val);
              Inc(I);

              If (I < TokenCount) And (TokenPool[I].Kind = TK_PUNCT) And
                 (TokenPool[I].Val = ':') Then
                Inc(I)
              Else
              Begin
                While (I < TokenCount) And
                      Not ((TokenPool[I].Kind = TK_PUNCT) And
                           (TokenPool[I].Val = ';')) And
                      Not ((TokenPool[I].Kind = TK_KEYWORD) And
                           (StrUpperCase(TokenPool[I].Val) = 'END')) Do
                  Inc(I);
                If (I < TokenCount) And (TokenPool[I].Kind = TK_PUNCT) And
                   (TokenPool[I].Val = ';') Then Inc(I);
                Continue;
              End;

              FTName := 'INTEGER';
              If (I < TokenCount) And
                 ((TokenPool[I].Kind = TK_IDENT) Or
                  (TokenPool[I].Kind = TK_KEYWORD)) Then
              Begin
                FTName := StrUpperCase(TokenPool[I].Val);
                Inc(I);
              End;

              FSz := TPTypeSizeof(FTName);
              If FSz < 0 Then
              Begin
                FTIdx := TypeFindByName(FTName);
                If FTIdx >= 0 Then
                  FSz := TypeTab[FTIdx].Size
                Else
                  FSz := 4;
              End;
              FTIdx := TypeFindByName(FTName);
              If FTIdx < 0 Then FTIdx := TY_IDX_INTEGER;

              If (TIdx >= 0) And (FC < MAX_FIELDS) Then
              Begin
                TypeTab[TIdx].Fields[FC].Name    := FName;
                TypeTab[TIdx].Fields[FC].TypeIdx := FTIdx;
                TypeTab[TIdx].Fields[FC].Offset  := FOfs;
                Inc(FC);
                TypeTab[TIdx].FieldCount := FC;
                FOfs := FOfs + FSz;
                TypeTab[TIdx].Size := FOfs;
              End;

              If (I < TokenCount) And (TokenPool[I].Kind = TK_PUNCT) And
                 (TokenPool[I].Val = ';') Then
                Inc(I);
            End;

            SIdx := SymAdd(TName, SK_TYPE, TIdx);

            If (I < TokenCount) And (TokenPool[I].Kind = TK_PUNCT) And
               (TokenPool[I].Val = ';') Then
              Inc(I);
            Continue;
          End;

          { --- Enumeration : (val1, val2, ...) --- }
          If (TokenPool[I].Kind = TK_PUNCT) And (TokenPool[I].Val = '(') Then
          Begin
            Inc(I);
            TIdx := TypeAdd(TYK_ENUM, TName, 4, 4, False, -1);
            FC := 0;
            While (I < TokenCount) And
                  Not ((TokenPool[I].Kind = TK_PUNCT) And
                       (TokenPool[I].Val = ')')) Do
            Begin
              If (TokenPool[I].Kind = TK_IDENT) Then
              Begin
                SIdx := SymAdd(StrUpperCase(TokenPool[I].Val), SK_CONST, TIdx);
                If SIdx >= 0 Then
                  SymTab[SIdx].ImmVal := FC;
                Inc(FC);
              End;
              Inc(I);
            End;
            If I < TokenCount Then Inc(I); { skip ')' }
            If TIdx >= 0 Then
              TypeTab[TIdx].EnumCount := FC;

            SIdx := SymAdd(TName, SK_TYPE, TIdx);

            While (I < TokenCount) And
                  Not ((TokenPool[I].Kind = TK_PUNCT) And
                       (TokenPool[I].Val = ';')) Do
              Inc(I);
            If I < TokenCount Then Inc(I);
            Continue;
          End;

          { --- Type alias or subrange --- }
          If (I < TokenCount) And (TokenPool[I].Kind = TK_INTEGER) Then
          Begin
            { Subrange: lo..hi }
            ArrLo := TokenPool[I].IntVal;
            Inc(I);
            If (I < TokenCount) And (TokenPool[I].Kind = TK_PUNCT) And
               (TokenPool[I].Val = '..') Then
            Begin
              Inc(I);
              ArrHi := 0;
              If (I < TokenCount) And (TokenPool[I].Kind = TK_INTEGER) Then
              Begin
                ArrHi := TokenPool[I].IntVal;
                Inc(I);
              End;
              TIdx := TypeAdd(TYK_SUBRANGE, TName, 4, 4, False, TY_IDX_INTEGER);
              If TIdx >= 0 Then
              Begin
                TypeTab[TIdx].Lo := ArrLo;
                TypeTab[TIdx].Hi := ArrHi;
              End;
              SIdx := SymAdd(TName, SK_TYPE, TIdx);
            End;
          End
          Else If (I < TokenCount) And
                  ((TokenPool[I].Kind = TK_IDENT) Or
                   (TokenPool[I].Kind = TK_KEYWORD)) Then
          Begin
            { Type alias: Type NewName = OldName }
            BaseTN := StrUpperCase(TokenPool[I].Val);
            Inc(I);
            BTIdx := TypeFindByName(BaseTN);
            If BTIdx >= 0 Then
            Begin
              TIdx := TypeAdd(TypeTab[BTIdx].Kind, TName,
                TypeTab[BTIdx].Size, TypeTab[BTIdx].Align,
                TypeTab[BTIdx].IsUnsigned, BTIdx);
              If (TIdx >= 0) And (TypeTab[BTIdx].Kind = TYK_RECORD) Then
              Begin
                TypeTab[TIdx].FieldCount := TypeTab[BTIdx].FieldCount;
                TypeTab[TIdx].Fields := TypeTab[BTIdx].Fields;
              End;
            End
            Else
              TIdx := TypeAdd(TYK_INTEGER, TName, 4, 4, False, -1);
            SIdx := SymAdd(TName, SK_TYPE, TIdx);
          End;

          { Avancer au ';' }
          While (I < TokenCount) And
                Not ((TokenPool[I].Kind = TK_PUNCT) And
                     (TokenPool[I].Val = ';')) Do
            Inc(I);
          If I < TokenCount Then Inc(I);
        End;
        Continue;
      End;
    End;

    Inc(I);
  End;
End;

{ ------------------------------------------------------------ }
{ FindFieldOffset : trouver l offset d un champ dans un type   }
{ record ou objet. Retourne l offset, ou -1 si non trouve.     }
{ FSize retourne la taille du champ.                           }
{ ------------------------------------------------------------ }

Function FindFieldOffset(TIdx : Integer; Const FName : TString;
                         Var FSize : Integer) : Integer;
Var
  J    : Integer;
  Up   : TString;
  FTI  : Integer;
Begin
  FindFieldOffset := -1;
  FSize := 4;
  If (TIdx < 0) Or (TIdx >= TypeCount) Then Exit;
  If (TypeTab[TIdx].Kind <> TYK_RECORD) And
     (TypeTab[TIdx].Kind <> TYK_OBJECT) Then Exit;

  Up := StrUpperCase(FName);
  For J := 0 To TypeTab[TIdx].FieldCount - 1 Do
  Begin
    If TypeTab[TIdx].Fields[J].Name = Up Then
    Begin
      FindFieldOffset := TypeTab[TIdx].Fields[J].Offset;
      FTI := TypeTab[TIdx].Fields[J].TypeIdx;
      If (FTI >= 0) And (FTI < TypeCount) Then
        FSize := TypeTab[FTI].Size
      Else
        FSize := 4;
      Exit;
    End;
  End;
End;

{ ------------------------------------------------------------ }
{ GetVarTypeIdx : retourne le TypeIdx d une variable locale,   }
{ parametre ou globale.                                        }
{ ------------------------------------------------------------ }

Function GetVarTypeIdx(PI : Integer; Const Name : TString) : Integer;
Var
  LI, ParI, SI : Integer;
  Up : TString;
Begin
  GetVarTypeIdx := -1;
  Up := StrUpperCase(Name);

  If PI >= 0 Then
  Begin
    LI := FindLocal(PI, Up);
    If LI >= 0 Then
    Begin
      GetVarTypeIdx := ProcTab[PI].Locals[LI].TypeIdx;
      Exit;
    End;
    ParI := FindParam(PI, Up);
    If ParI >= 0 Then
    Begin
      GetVarTypeIdx := ProcTab[PI].Params[ParI].TypeIdx;
      Exit;
    End;
  End;

  SI := SymFind(Up);
  If SI >= 0 Then
  Begin
    GetVarTypeIdx := SymTab[SI].TypeIdx;
    Exit;
  End;
End;
{ ============================================================ }
{ TODO 10 - EXPRESSIONS PRIMAIRES                 [IMPLEMENTE] }
{ ============================================================ }

Var
  { Curseur de lecture dans TokenPool pour le parsing du corps }
  EP      : Integer;   { position courante dans TokenPool         }
  EPEnd   : Integer;   { borne superieure (exclusive)             }
  RetLbl  : TString;   { label de retour de la fonction courante  }
  LastPrimaryName : TString; { dernier ident charge par ParsePrimary }
  LastVarTypeIdx : Integer; { type index du dernier ident charge }

  { Pile de boucles pour Break/Continue (TODO 13) }
  LoopBreakLbl : Array[0..31] Of TString;
  LoopContLbl  : Array[0..31] Of TString;
  LoopTop      : Integer;

{ ------------------------------------------------------------ }
{ EPAtEnd : le curseur est-il a la fin ?                       }
{ ------------------------------------------------------------ }

Function EPAtEnd : Boolean;
Begin
  EPAtEnd := (EP >= EPEnd);
End;

{ ------------------------------------------------------------ }
{ EPPeek : retourne la valeur uppercased du token courant       }
{ sans avancer                                                  }
{ ------------------------------------------------------------ }

Function EPPeek : TString;
Begin
  If EP < EPEnd Then
    EPPeek := StrUpperCase(TokenPool[EP].Val)
  Else
    EPPeek := '';
End;

{ ------------------------------------------------------------ }
{ EPMatch : si le token courant correspond (insensible casse), }
{ avancer et retourner True                                     }
{ ------------------------------------------------------------ }

Function EPMatch(Const S : TString) : Boolean;
Begin
  EPMatch := False;
  If (EP < EPEnd) And (StrUpperCase(TokenPool[EP].Val) = S) Then
  Begin
    Inc(EP);
    EPMatch := True;
  End;
End;

{ ------------------------------------------------------------ }
{ GenLoadVar : generer le code pour charger une variable dans   }
{ EAX (ou MOVZX pour les bytes/chars/booleans)                 }
{ ------------------------------------------------------------ }

Procedure GenLoadVar(PI : Integer; Const Name : TString);
Var
  LI, ParI, SI : Integer;
  Up           : TString;
  Ref          : TString;
Begin
  Up := StrUpperCase(Name);
  LastVarTypeIdx := GetVarTypeIdx(PI, Up);
  If PI >= 0 Then
  Begin
    { Lecture du resultat de la fonction : FuncName ou Result }
    { Result n est utilise que s il n y a pas de variable locale nommee RESULT }
    If ProcTab[PI].IsFunction And
       ((ProcTab[PI].Name = Up) Or
        ((Up = 'RESULT') And (FindLocal(PI, 'RESULT') < 0))) Then
    Begin
      EmitInstr('MOV EAX,DWORD PTR ' + EBPOfs(ProcTab[PI].RetOffset));
      Exit;
    End;

    LI := FindLocal(PI, Up);
    If LI >= 0 Then
    Begin
      If (ProcTab[PI].Locals[LI].TypeIdx >= 0) And
         (ProcTab[PI].Locals[LI].TypeIdx < TypeCount) And
         ((TypeTab[ProcTab[PI].Locals[LI].TypeIdx].Kind = TYK_RECORD) Or
          (TypeTab[ProcTab[PI].Locals[LI].TypeIdx].Kind = TYK_ARRAY) Or
          (TypeTab[ProcTab[PI].Locals[LI].TypeIdx].Kind = TYK_OBJECT) Or
          (TypeTab[ProcTab[PI].Locals[LI].TypeIdx].Kind = TYK_SET) Or
          (TypeTab[ProcTab[PI].Locals[LI].TypeIdx].Kind = TYK_STRING)) Then
      Begin
        EmitInstr('LEA EAX,' + EBPOfs(ProcTab[PI].Locals[LI].Offset));
        Exit;
      End;
      If ProcTab[PI].Locals[LI].Size = 1 Then
        EmitInstr('MOVZX EAX,BYTE PTR ' + EBPOfs(ProcTab[PI].Locals[LI].Offset))
      Else
        EmitInstr('MOV EAX,DWORD PTR ' + EBPOfs(ProcTab[PI].Locals[LI].Offset));
      Exit;
    End;

    { Chercher parametre }
    ParI := FindParam(PI, Up);
    If ParI >= 0 Then
    Begin
      If ProcTab[PI].Params[ParI].IsVar Then
      Begin
        EmitInstr('MOV EBX,DWORD PTR ' + EBPOfs(ProcTab[PI].Params[ParI].Offset));
        EmitInstr('MOV EAX,[EBX]');
      End
      Else
        EmitInstr('MOV EAX,DWORD PTR ' + EBPOfs(ProcTab[PI].Params[ParI].Offset));
      Exit;
    End;
  End;

  { Constante nommee }
  SI := SymFind(Up);
  If SI >= 0 Then
  Begin
    If SymTab[SI].Kind = SK_CONST Then
    Begin
      EmitInstr('MOV EAX,' + IntToStr_(SymTab[SI].ImmVal));
      Exit;
    End;
    If SymTab[SI].Kind = SK_VAR Then
    Begin
      Ref := SymTab[SI].MangledName;
      If (SymTab[SI].TypeIdx >= 0) And (SymTab[SI].TypeIdx < TypeCount) And
         ((TypeTab[SymTab[SI].TypeIdx].Kind = TYK_RECORD) Or
          (TypeTab[SymTab[SI].TypeIdx].Kind = TYK_ARRAY) Or
          (TypeTab[SymTab[SI].TypeIdx].Kind = TYK_OBJECT) Or
          (TypeTab[SymTab[SI].TypeIdx].Kind = TYK_SET) Or
          (TypeTab[SymTab[SI].TypeIdx].Kind = TYK_STRING)) Then
      Begin
        EmitInstr('LEA EAX,[' + Ref + ']');
        Exit;
      End;
      If TypeSizeofIdx(SymTab[SI].TypeIdx) = 1 Then
        EmitInstr('MOVZX EAX,BYTE PTR [' + Ref + ']')
      Else
        EmitInstr('MOV EAX,DWORD PTR [' + Ref + ']');
      Exit;
    End;
  End;

  { Par defaut : globale }
  If (LastVarTypeIdx >= 0) And (LastVarTypeIdx < TypeCount) And
     ((TypeTab[LastVarTypeIdx].Kind = TYK_RECORD) Or
      (TypeTab[LastVarTypeIdx].Kind = TYK_ARRAY) Or
      (TypeTab[LastVarTypeIdx].Kind = TYK_OBJECT) Or
      (TypeTab[LastVarTypeIdx].Kind = TYK_SET) Or
      (TypeTab[LastVarTypeIdx].Kind = TYK_STRING)) Then
    EmitInstr('LEA EAX,[' + TP_VAR_PFX + Up + ']')
  Else
    EmitInstr('MOV EAX,DWORD PTR [' + TP_VAR_PFX + Up + ']');
End;

{ ------------------------------------------------------------ }
{ GenStoreVar : generer le code pour stocker EAX dans une      }
{ variable                                                      }
{ ------------------------------------------------------------ }

Procedure GenStoreVar(PI : Integer; Const Name : TString);
Var
  LI, ParI, SI : Integer;
  Up           : TString;
  Ref          : TString;
  VarTI        : Integer;
Begin
  Up := StrUpperCase(Name);

  { Variable locale (seulement si dans une proc) }
  If PI >= 0 Then
  Begin
    { Affectation du resultat de la fonction : FuncName := expr ou Result := expr }
    { Result n est utilise que s il n y a pas de variable locale nommee RESULT }
    If ProcTab[PI].IsFunction And
       ((ProcTab[PI].Name = Up) Or
        ((Up = 'RESULT') And (FindLocal(PI, 'RESULT') < 0))) Then
    Begin
      EmitInstr('MOV DWORD PTR ' + EBPOfs(ProcTab[PI].RetOffset) + ',EAX');
      Exit;
    End;

    LI := FindLocal(PI, Up);
    If LI >= 0 Then
    Begin
      VarTI := ProcTab[PI].Locals[LI].TypeIdx;
      { String : copier la chaine (EAX = src ptr) }
      If (VarTI >= 0) And (VarTI < TypeCount) And
         (TypeTab[VarTI].Kind = TYK_STRING) Then
      Begin
        EmitInstr('MOV ESI,EAX');
        EmitInstr('LEA EDI,' + EBPOfs(ProcTab[PI].Locals[LI].Offset));
        EmitInstr('CALL ' + TP_RT_PFX + 'STRCPY');
        Exit;
      End;
      If ProcTab[PI].Locals[LI].Size = 1 Then
        EmitInstr('MOV BYTE PTR ' + EBPOfs(ProcTab[PI].Locals[LI].Offset) + ',AL')
      Else
        EmitInstr('MOV DWORD PTR ' + EBPOfs(ProcTab[PI].Locals[LI].Offset) + ',EAX');
      Exit;
    End;

    { Parametre }
    ParI := FindParam(PI, Up);
    If ParI >= 0 Then
    Begin
      If ProcTab[PI].Params[ParI].IsVar Then
      Begin
        EmitInstr('MOV EBX,DWORD PTR ' + EBPOfs(ProcTab[PI].Params[ParI].Offset));
        EmitInstr('MOV [EBX],EAX');
      End
      Else
        EmitInstr('MOV DWORD PTR ' + EBPOfs(ProcTab[PI].Params[ParI].Offset) + ',EAX');
      Exit;
    End;
  End;

  { Symbole global }
  SI := SymFind(Up);
  If SI >= 0 Then
  Begin
    If SymTab[SI].Kind = SK_VAR Then
    Begin
      Ref := SymTab[SI].MangledName;
      VarTI := SymTab[SI].TypeIdx;
      { String : copier la chaine (EAX = src ptr) }
      If (VarTI >= 0) And (VarTI < TypeCount) And
         (TypeTab[VarTI].Kind = TYK_STRING) Then
      Begin
        EmitInstr('MOV ESI,EAX');
        EmitInstr('LEA EDI,[' + Ref + ']');
        EmitInstr('CALL ' + TP_RT_PFX + 'STRCPY');
        Exit;
      End;
      If TypeSizeofIdx(VarTI) = 1 Then
        EmitInstr('MOV BYTE PTR [' + Ref + '],AL')
      Else
        EmitInstr('MOV DWORD PTR [' + Ref + '],EAX');
      Exit;
    End;
  End;

  { Par defaut : variable globale standard }
  VarTI := GetVarTypeIdx(PI, Up);
  If (VarTI >= 0) And (VarTI < TypeCount) And
     (TypeTab[VarTI].Kind = TYK_STRING) Then
  Begin
    EmitInstr('MOV ESI,EAX');
    EmitInstr('LEA EDI,[' + TP_VAR_PFX + Up + ']');
    EmitInstr('CALL ' + TP_RT_PFX + 'STRCPY');
  End
  Else
    EmitInstr('MOV DWORD PTR [' + TP_VAR_PFX + Up + '],EAX');
End;

{ ------------------------------------------------------------ }
{ GenLoadAddr : generer LEA EAX, [variable]                    }
{ ------------------------------------------------------------ }

Procedure GenLoadAddr(PI : Integer; Const Name : TString);
Var
  LI, ParI, SI : Integer;
  Up           : TString;
Begin
  Up := StrUpperCase(Name);

  If PI >= 0 Then
  Begin
    LI := FindLocal(PI, Up);
    If LI >= 0 Then
    Begin
      EmitInstr('LEA EAX,' + EBPOfs(ProcTab[PI].Locals[LI].Offset));
      Exit;
    End;

    ParI := FindParam(PI, Up);
    If ParI >= 0 Then
    Begin
      If ProcTab[PI].Params[ParI].IsVar Then
        EmitInstr('MOV EAX,DWORD PTR ' + EBPOfs(ProcTab[PI].Params[ParI].Offset))
      Else
        EmitInstr('LEA EAX,' + EBPOfs(ProcTab[PI].Params[ParI].Offset));
      Exit;
    End;
  End;

  SI := SymFind(Up);
  If SI >= 0 Then
  Begin
    If (SymTab[SI].Kind = SK_VAR) Then
    Begin
      EmitInstr('LEA EAX,[' + SymTab[SI].MangledName + ']');
      Exit;
    End;
  End;

  EmitInstr('LEA EAX,[' + TP_VAR_PFX + Up + ']');
End;

{ ------------------------------------------------------------ }
{ Forward declarations TODO 10                                  }
{ ------------------------------------------------------------ }

Procedure ParseExpr(PI : Integer); Forward;
Procedure ParseExprPrec(PI : Integer; MinPrec : Integer); Forward;
Procedure ParseBody(PI : Integer); Forward;

{ ------------------------------------------------------------ }
{ Forward declarations TODO 13                                  }
{ ------------------------------------------------------------ }

Procedure ParseStmt(PI : Integer); Forward;
Procedure ParseIfStmt(PI : Integer); Forward;
Procedure ParseCaseStmt(PI : Integer); Forward;
Procedure ParseWhileStmt(PI : Integer); Forward;
Procedure ParseRepeatStmt(PI : Integer); Forward;
Procedure ParseForStmt(PI : Integer); Forward;
Procedure ParseGotoStmt(PI : Integer); Forward;
Procedure ParseAsmBlock(PI : Integer); Forward;

{ ------------------------------------------------------------ }
{ ParseFuncCall : parser un appel de procedure/fonction         }
{ nom(arg1, arg2, ...) -> PUSH args, CALL _TPF_nom             }
{ Convention stdcall : args gauche-a-droite                     }
{ ------------------------------------------------------------ }

Procedure ParseFuncCall(PI : Integer; Const ProcName : TString);
Var
  ArgCount  : Integer;
  Up        : TString;
  SI        : Integer;
  MName     : TString;
  CalledPI  : Integer;
  J         : Integer;
  IsVarArg  : Boolean;
  ArgName   : TString;
Begin
  Up := StrUpperCase(ProcName);
  ArgCount := 0;

  { Trouver le symbole de la procedure/fonction }
  SI := SymFind(Up);
  If SI >= 0 Then
    MName := SymTab[SI].MangledName
  Else
    MName := TP_FUNC_PFX + Up;

  { Trouver l index dans ProcTab pour connaitre les params VAR }
  CalledPI := -1;
  For J := 0 To ProcCount - 1 Do
    If ProcTab[J].Name = Up Then
    Begin
      CalledPI := J;
      Break;
    End;

  { Consommer '(' si present }
  If EPMatch('(') Then
  Begin
    { Compter et compiler les arguments }
    If Not EPMatch(')') Then
    Begin
      Repeat
        { Determiner si le parametre courant est VAR }
        IsVarArg := False;
        If (CalledPI >= 0) And (ArgCount < ProcTab[CalledPI].ParamCount) Then
          IsVarArg := ProcTab[CalledPI].Params[ArgCount].IsVar;

        If IsVarArg Then
        Begin
          { Parametre VAR : pousser l adresse de la variable }
          If (Not EPAtEnd) And
             ((TokenPool[EP].Kind = TK_IDENT) Or
              (TokenPool[EP].Kind = TK_KEYWORD)) Then
          Begin
            ArgName := TokenPool[EP].Val;
            Inc(EP);
            GenLoadAddr(PI, ArgName);
            EmitInstr('PUSH EAX');
          End
          Else
          Begin
            { Fallback : evaluer et pousser (pas ideal pour VAR) }
            ParseExpr(PI);
            EmitInstr('PUSH EAX');
          End;
        End
        Else
        Begin
          { Parametre normal : evaluer et pousser la valeur }
          ParseExpr(PI);
          EmitInstr('PUSH EAX');
        End;
        Inc(ArgCount);
      Until Not EPMatch(',');
      If Not EPMatch(')') Then
        Inc(EP); { sauter le ')' manquant }
    End;
  End;

  EmitInstr('CALL ' + MName);

  { Nettoyer la pile (convention cdecl/stdcall-like pour nos procs Pascal) }
  If ArgCount > 0 Then
    EmitInstr('ADD ESP,' + IntToStr_(ArgCount * 4));
End;

{ ------------------------------------------------------------ }
{ ParsePrimary : parser une expression primaire                 }
{ Resultat dans EAX                                             }
{ ------------------------------------------------------------ }

Procedure ParsePrimary(PI : Integer);
Var
  Up     : TString;
  Lbl    : TString;
  SI     : Integer;
  LI     : Integer;
  ParI   : Integer;
Begin
  LastPrimaryName := '';
  LastVarTypeIdx := -1;

  If EPAtEnd Then Exit;

  { Litteral entier }
  If TokenPool[EP].Kind = TK_INTEGER Then
  Begin
    EmitInstr('MOV EAX,' + IntToStr_(TokenPool[EP].IntVal));
    Inc(EP);
    Exit;
  End;

  { Litteral caractere }
  If TokenPool[EP].Kind = TK_CHAR Then
  Begin
    EmitInstr('MOV EAX,' + IntToStr_(TokenPool[EP].IntVal));
    Inc(EP);
    Exit;
  End;

  { Litteral chaine }
  If TokenPool[EP].Kind = TK_STRING Then
  Begin
    Lbl := DataGetOrAddStr(TokenPool[EP].Val);
    EmitInstr('LEA EAX,[' + Lbl + ']');
    LastVarTypeIdx := TY_IDX_STRING;
    Inc(EP);
    Exit;
  End;

  { Mot-cle ou identificateur }
  If (TokenPool[EP].Kind = TK_KEYWORD) Or
     (TokenPool[EP].Kind = TK_IDENT) Then
  Begin
    Up := StrUpperCase(TokenPool[EP].Val);

    { TRUE / FALSE }
    If Up = 'TRUE' Then
    Begin
      EmitInstr('MOV EAX,1');
      Inc(EP);
      Exit;
    End;
    If Up = 'FALSE' Then
    Begin
      EmitInstr('XOR EAX,EAX');
      Inc(EP);
      Exit;
    End;

    { NIL }
    If Up = 'NIL' Then
    Begin
      EmitInstr('XOR EAX,EAX');
      Inc(EP);
      Exit;
    End;

    { SIZEOF(T) / SIZEOF(V) }
    If Up = 'SIZEOF' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        If Not EPAtEnd Then
        Begin
          Up := StrUpperCase(TokenPool[EP].Val);
          SI := TypeFindByName(Up);
          If SI >= 0 Then
            EmitInstr('MOV EAX,' + IntToStr_(TypeSizeofIdx(SI)))
          Else
          Begin
            { Chercher comme variable }
            LI := FindLocal(PI, Up);
            If LI >= 0 Then
              EmitInstr('MOV EAX,' + IntToStr_(ProcTab[PI].Locals[LI].Size))
            Else
            Begin
              SI := SymFind(Up);
              If (SI >= 0) And (SymTab[SI].TypeIdx >= 0) Then
                EmitInstr('MOV EAX,' + IntToStr_(TypeSizeofIdx(SymTab[SI].TypeIdx)))
              Else
                EmitInstr('MOV EAX,4');
            End;
          End;
          Inc(EP);
        End;
        EPMatch(')');
      End;
      Exit;
    End;

    { ORD(x) -> resultat dans EAX (valeur ordinale) }
    If Up = 'ORD' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        { EAX contient deja la valeur ordinale }
        EmitInstr('AND EAX,0FFh');
        EPMatch(')');
      End;
      Exit;
    End;

    { CHR(x) -> resultat dans EAX (caractere) }
    If Up = 'CHR' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        EmitInstr('AND EAX,0FFh');
        EPMatch(')');
      End;
      Exit;
    End;

    { SUCC(x) -> x + 1 }
    If Up = 'SUCC' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        EmitInstr('INC EAX');
        EPMatch(')');
      End;
      Exit;
    End;

    { PRED(x) -> x - 1 }
    If Up = 'PRED' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        EmitInstr('DEC EAX');
        EPMatch(')');
      End;
      Exit;
    End;

    { LO(x) -> octet bas }
    If Up = 'LO' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        EmitInstr('AND EAX,0FFh');
        EPMatch(')');
      End;
      Exit;
    End;

    { HI(x) -> octet haut }
    If Up = 'HI' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        EmitInstr('SHR EAX,8');
        EmitInstr('AND EAX,0FFh');
        EPMatch(')');
      End;
      Exit;
    End;

    { ABS(x) -> valeur absolue }
    If Up = 'ABS' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        EmitInstr('CDQ');
        EmitInstr('XOR EAX,EDX');
        EmitInstr('SUB EAX,EDX');
        EPMatch(')');
      End;
      Exit;
    End;

    { SQR(x) -> x * x }
    If Up = 'SQR' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        EmitInstr('IMUL EAX,EAX');
        EPMatch(')');
      End;
      Exit;
    End;

    { ODD(x) -> x AND 1 }
    If Up = 'ODD' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        EmitInstr('AND EAX,1');
        EPMatch(')');
      End;
      Exit;
    End;

    { SWAP(x) -> echanger octets bas et haut du word }
    If Up = 'SWAP' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        EmitInstr('XCHG AL,AH');
        EPMatch(')');
      End;
      Exit;
    End;

    { ROUND(x) / TRUNC(x) -> stub : juste retourner la valeur }
    If (Up = 'ROUND') Or (Up = 'TRUNC') Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        EPMatch(')');
      End;
      Exit;
    End;

    { LOW(T) / HIGH(T) }
    If (Up = 'LOW') Or (Up = 'HIGH') Then
    Begin
      Lbl := Up;
      Inc(EP);
      If EPMatch('(') Then
      Begin
        If Not EPAtEnd Then
        Begin
          Up := StrUpperCase(TokenPool[EP].Val);
          SI := TypeFindByName(Up);
          If SI >= 0 Then
          Begin
            If Lbl = 'LOW' Then
              EmitInstr('MOV EAX,' + IntToStr_(TypeTab[SI].Lo))
            Else
              EmitInstr('MOV EAX,' + IntToStr_(TypeTab[SI].Hi));
          End
          Else
          Begin
            If Lbl = 'LOW' Then
              EmitInstr('MOV EAX,0')
            Else
              EmitInstr('MOV EAX,0');
          End;
          Inc(EP);
        End;
        EPMatch(')');
      End;
      Exit;
    End;

    { INC(x[,n]) }
    If Up = 'INC' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        If Not EPAtEnd Then
        Begin
          Lbl := TokenPool[EP].Val;
          Inc(EP);
          If EPMatch(',') Then
          Begin
            ParseExpr(PI);
            EmitInstr('MOV ECX,EAX');
            GenLoadVar(PI, Lbl);
            EmitInstr('ADD EAX,ECX');
          End
          Else
          Begin
            GenLoadVar(PI, Lbl);
            EmitInstr('INC EAX');
          End;
          GenStoreVar(PI, Lbl);
        End;
        EPMatch(')');
      End;
      Exit;
    End;

    { DEC(x[,n]) }
    If Up = 'DEC' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        If Not EPAtEnd Then
        Begin
          Lbl := TokenPool[EP].Val;
          Inc(EP);
          If EPMatch(',') Then
          Begin
            ParseExpr(PI);
            EmitInstr('MOV ECX,EAX');
            GenLoadVar(PI, Lbl);
            EmitInstr('SUB EAX,ECX');
          End
          Else
          Begin
            GenLoadVar(PI, Lbl);
            EmitInstr('DEC EAX');
          End;
          GenStoreVar(PI, Lbl);
        End;
        EPMatch(')');
      End;
      Exit;
    End;

    { NEW(p) -> HeapAlloc }
    If Up = 'NEW' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        If Not EPAtEnd Then
        Begin
          Lbl := TokenPool[EP].Val;
          Inc(EP);
          EmitInstr('PUSH 4');
          EmitInstr('PUSH 8');   { HEAP_ZERO_MEMORY }
          EmitInstr('PUSH DWORD PTR [HHEAP]');
          EmitInstr('CALL HeapAlloc');
          GenStoreVar(PI, Lbl);
        End;
        EPMatch(')');
      End;
      Exit;
    End;

    { DISPOSE(p) -> HeapFree }
    If Up = 'DISPOSE' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        If Not EPAtEnd Then
        Begin
          Lbl := TokenPool[EP].Val;
          Inc(EP);
          GenLoadVar(PI, Lbl);
          EmitInstr('PUSH EAX');
          EmitInstr('PUSH 0');
          EmitInstr('PUSH DWORD PTR [HHEAP]');
          EmitInstr('CALL HeapFree');
        End;
        EPMatch(')');
      End;
      Exit;
    End;

    { ---- TODO 16 : Builtins chaines ---- }

    { LENGTH(S) -> longueur ASCIIZ dans EAX }
    If Up = 'LENGTH' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        { EAX = pointeur vers chaine ASCIIZ }
        EmitInstr('MOV ESI,EAX');
        EmitInstr('CALL ' + TP_RT_PFX + 'STRLEN');
        EPMatch(')');
      End;
      Exit;
    End;

    { COPY(S, Pos, Len) -> sous-chaine dans STRBUF1 }
    If Up = 'COPY' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        { S -> ESI }
        ParseExpr(PI);
        EmitInstr('PUSH EAX');
        EPMatch(',');
        { Pos -> EBX }
        ParseExpr(PI);
        EmitInstr('PUSH EAX');
        EPMatch(',');
        { Len -> ECX }
        ParseExpr(PI);
        EmitInstr('MOV ECX,EAX');
        EmitInstr('POP EBX');      { Pos }
        EmitInstr('POP ESI');      { Source ptr }
        EmitInstr('CALL ' + TP_RT_PFX + 'COPY');
        { Resultat : EAX = pointeur vers STRBUF1 }
        LastVarTypeIdx := TY_IDX_STRING;
        EPMatch(')');
      End;
      Exit;
    End;

    { POS(SubStr, S) -> position (1-based) ou 0 }
    If Up = 'POS' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        { SubStr -> EDI }
        ParseExpr(PI);
        EmitInstr('PUSH EAX');
        EPMatch(',');
        { S -> ESI }
        ParseExpr(PI);
        EmitInstr('MOV ESI,EAX');
        EmitInstr('POP EDI');
        EmitInstr('CALL ' + TP_RT_PFX + 'POS');
        { Resultat : EAX = position (1-based) ou 0 }
        EPMatch(')');
      End;
      Exit;
    End;

    { CONCAT(S1, S2, ...) -> chaine concatenee dans STRBUF1 }
    If Up = 'CONCAT' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        { Premier argument }
        ParseExpr(PI);
        { EAX = pointeur vers s1, copier dans STRBUF1 }
        EmitInstr('MOV ESI,EAX');
        EmitInstr('LEA EDI,[STRBUF1]');
        EmitInstr('CALL ' + TP_RT_PFX + 'STRCPY');
        { Arguments suivants : concatener }
        While Not EPAtEnd Do
        Begin
          If (TokenPool[EP].Kind = TK_PUNCT) And (TokenPool[EP].Val = ',') Then
          Begin
            Inc(EP);
            ParseExpr(PI);
            EmitInstr('MOV EDI,EAX');
            EmitInstr('LEA ESI,[STRBUF1]');
            EmitInstr('CALL ' + TP_RT_PFX + 'CONCAT');
          End
          Else
            Break;
        End;
        EmitInstr('LEA EAX,[STRBUF1]');
        EPMatch(')');
      End;
      Exit;
    End;

    { UPCASE(Ch) -> majuscule }
    If Up = 'UPCASE' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        { EAX = caractere, convertir en majuscule }
        Lbl := LabelGen;
        EmitInstr('CMP AL,97');   { 'a' }
        EmitInstr('JB ' + Lbl);
        EmitInstr('CMP AL,122');  { 'z' }
        EmitInstr('JA ' + Lbl);
        EmitInstr('SUB AL,32');
        EmitLabel(Lbl);
        EPMatch(')');
      End;
      Exit;
    End;

    { Appel de procedure/fonction ? }
    SI := SymFind(Up);
    If (SI >= 0) And
       ((SymTab[SI].Kind = SK_PROC) Or (SymTab[SI].Kind = SK_FUNC)) Then
    Begin
      Inc(EP);
      ParseFuncCall(PI, Up);
      Exit;
    End;

    { Verificr aussi dans ProcTab }
    If SI < 0 Then
    Begin
      LI := 0;
      While LI < ProcCount Do
      Begin
        If ProcTab[LI].Name = Up Then
        Begin
          Inc(EP);
          ParseFuncCall(PI, Up);
          Exit;
        End;
        Inc(LI);
      End;
    End;

    { Variable ou constante : charger dans EAX }
    LastPrimaryName := Up;
    LastVarTypeIdx := GetVarTypeIdx(PI, Up);
    GenLoadVar(PI, Up);
    Inc(EP);
    Exit;
  End;

  { Expression entre parentheses }
  If (TokenPool[EP].Kind = TK_PUNCT) And (TokenPool[EP].Val = '(') Then
  Begin
    Inc(EP);
    ParseExpr(PI);
    EPMatch(')');
    Exit;
  End;

  { Token non reconnu : avancer }
  Inc(EP);
End;

{ ------------------------------------------------------------ }
{ ParsePostfix : parser les suffixes apres une expression       }
{ primaire : [index], .champ, ^dereference                     }
{ ------------------------------------------------------------ }

Procedure ParsePostfix(PI : Integer);
Var
  Up : TString;
  ElemSz : Integer;
  FOfs : Integer;
  FSize : Integer;
  SavedTypeIdx : Integer;
Begin
  While Not EPAtEnd Do
  Begin
    { Dereference : ^ }
    If (TokenPool[EP].Kind = TK_OP) And (TokenPool[EP].Val = '^') Then
    Begin
      Inc(EP);
      EmitInstr('MOV EBX,EAX');
      EmitInstr('MOV EAX,[EBX]');
      Continue;
    End;

    { Acces tableau : [index] }
    If (TokenPool[EP].Kind = TK_PUNCT) And (TokenPool[EP].Val = '[') Then
    Begin
      Inc(EP);
      SavedTypeIdx := LastVarTypeIdx;  { sauvegarder le type avant ParseExpr }
      EmitInstr('PUSH EAX');         { sauvegarder adresse base }
      ParseExpr(PI);
      LastVarTypeIdx := SavedTypeIdx;  { restaurer le type du tableau }
      { EAX = index, [ESP] = base address }
      { Soustraire borne inferieure si necessaire }
      If (LastVarTypeIdx >= 0) And (LastVarTypeIdx < TypeCount) And
         (TypeTab[LastVarTypeIdx].Kind = TYK_ARRAY) And
         (TypeTab[LastVarTypeIdx].Lo <> 0) Then
        EmitInstr('SUB EAX,' + IntToStr_(TypeTab[LastVarTypeIdx].Lo));
      { Multiplier par la taille de l element }
      If (LastVarTypeIdx >= 0) And (LastVarTypeIdx < TypeCount) And
         (TypeTab[LastVarTypeIdx].Kind = TYK_ARRAY) And
         (TypeTab[LastVarTypeIdx].BaseTypeIdx >= 0) Then
      Begin
        ElemSz := TypeSizeofIdx(TypeTab[LastVarTypeIdx].BaseTypeIdx);
        If ElemSz = 1 Then
          { pas de multiplication }
        Else If ElemSz = 2 Then
          EmitInstr('SHL EAX,1')
        Else If ElemSz = 4 Then
          EmitInstr('SHL EAX,2')
        Else If ElemSz = 8 Then
          EmitInstr('SHL EAX,3')
        Else
          EmitInstr('IMUL EAX,' + IntToStr_(ElemSz));
        LastVarTypeIdx := TypeTab[LastVarTypeIdx].BaseTypeIdx;
      End
      Else
        EmitInstr('SHL EAX,2');  { par defaut DWORD }
      EmitInstr('POP EBX');
      EmitInstr('ADD EBX,EAX');
      { Charger la valeur selon la taille }
      If (LastVarTypeIdx >= 0) And (LastVarTypeIdx < TypeCount) Then
      Begin
        If TypeTab[LastVarTypeIdx].Size = 1 Then
          EmitInstr('MOVZX EAX,BYTE PTR [EBX]')
        Else If (TypeTab[LastVarTypeIdx].Kind = TYK_RECORD) Or
                (TypeTab[LastVarTypeIdx].Kind = TYK_OBJECT) Then
          EmitInstr('LEA EAX,[EBX]')
        Else
          EmitInstr('MOV EAX,[EBX]');
      End
      Else
        EmitInstr('MOV EAX,[EBX]');
      EPMatch(']');
      Continue;
    End;

    { Acces champ : .field (record/objet) }
    If (TokenPool[EP].Kind = TK_PUNCT) And (TokenPool[EP].Val = '.') Then
    Begin
      Inc(EP);
      If Not EPAtEnd Then
      Begin
        Up := StrUpperCase(TokenPool[EP].Val);
        Inc(EP);
        FSize := 4;
        FOfs := FindFieldOffset(LastVarTypeIdx, Up, FSize);
        If FOfs >= 0 Then
        Begin
          If FOfs > 0 Then
            EmitInstr('ADD EAX,' + IntToStr_(FOfs));
          { Mettre a jour le type courant }
          If (LastVarTypeIdx >= 0) And (LastVarTypeIdx < TypeCount) Then
          Begin
            For ElemSz := 0 To TypeTab[LastVarTypeIdx].FieldCount - 1 Do
              If TypeTab[LastVarTypeIdx].Fields[ElemSz].Name = Up Then
              Begin
                LastVarTypeIdx := TypeTab[LastVarTypeIdx].Fields[ElemSz].TypeIdx;
                Break;
              End;
          End;
          { Charger la valeur du champ }
          If (LastVarTypeIdx >= 0) And (LastVarTypeIdx < TypeCount) And
             ((TypeTab[LastVarTypeIdx].Kind = TYK_RECORD) Or
              (TypeTab[LastVarTypeIdx].Kind = TYK_OBJECT)) Then
            { EAX pointe deja sur le sous-record }
          Else If FSize = 1 Then
            EmitInstr('MOVZX EAX,BYTE PTR [EAX]')
          Else
            EmitInstr('MOV EAX,[EAX]');
        End
        Else
          EmitComment('champ inconnu: ' + Up);
      End;
      Continue;
    End;

    Break;
  End;
End;

{ ------------------------------------------------------------ }
{ ParseUnary : parser les operateurs unaires prefixes           }
{ NOT, @, -, +                                                  }
{ ------------------------------------------------------------ }

Procedure ParseUnary(PI : Integer);
Var
  Up : TString;
Begin
  If EPAtEnd Then Exit;

  Up := StrUpperCase(TokenPool[EP].Val);

  { NOT }
  If (TokenPool[EP].Kind = TK_KEYWORD) And (Up = 'NOT') Then
  Begin
    Inc(EP);
    ParseUnary(PI);
    EmitInstr('XOR EAX,1');
    Exit;
  End;

  { Negation unaire - }
  If (TokenPool[EP].Kind = TK_OP) And (TokenPool[EP].Val = '-') Then
  Begin
    Inc(EP);
    ParseUnary(PI);
    EmitInstr('NEG EAX');
    Exit;
  End;

  { Plus unaire + (no-op) }
  If (TokenPool[EP].Kind = TK_OP) And (TokenPool[EP].Val = '+') Then
  Begin
    Inc(EP);
    ParseUnary(PI);
    Exit;
  End;

  { Adresse @ }
  If (TokenPool[EP].Kind = TK_OP) And (TokenPool[EP].Val = '@') Then
  Begin
    Inc(EP);
    If Not EPAtEnd Then
    Begin
      Up := StrUpperCase(TokenPool[EP].Val);
      GenLoadAddr(PI, Up);
      Inc(EP);
    End;
    Exit;
  End;

  { Expression primaire }
  ParsePrimary(PI);
  ParsePostfix(PI);
End;

{ ============================================================ }
{ TODO 11 - EXPRESSIONS BINAIRES ET PRECEDENCE [IMPLEMENTE]     }
{ ============================================================ }

{ ------------------------------------------------------------ }
{ BinOpPrec : retourner le niveau de precedence d un operateur  }
{ binaire Pascal. 0 = pas un operateur binaire.                 }
{ Niveaux de precedence Pascal (plus haut = lie plus fort) :    }
{   3 : * / DIV MOD AND SHL SHR  (multiplicatif)               }
{   2 : + - OR XOR               (additif)                     }
{   1 : = <> < > <= >= IN        (relationnel)                  }
{ ------------------------------------------------------------ }

Function BinOpPrec(Const Op : TString) : Integer;
Var
  U : TString;
Begin
  U := Op;
  If (U = '*') Or (U = '/') Or (U = 'DIV') Or (U = 'MOD') Or
     (U = 'AND') Or (U = 'SHL') Or (U = 'SHR') Then
    BinOpPrec := 3
  Else If (U = '+') Or (U = '-') Or (U = 'OR') Or (U = 'XOR') Then
    BinOpPrec := 2
  Else If (U = '=') Or (U = '<>') Or (U = '<') Or (U = '>') Or
          (U = '<=') Or (U = '>=') Or (U = 'IN') Then
    BinOpPrec := 1
  Else
    BinOpPrec := 0;
End;

{ ------------------------------------------------------------ }
{ EmitBinOp : emettre le code ASM pour EAX op EBX              }
{ Le resultat doit rester dans EAX.                             }
{ ------------------------------------------------------------ }

Procedure EmitBinOp(Const Op : TString);
Var
  LblTrue, LblEnd : TString;
Begin
  { Arithmetique }
  If Op = '+' Then
    EmitInstr('ADD EAX,EBX')
  Else If Op = '-' Then
    EmitInstr('SUB EAX,EBX')
  Else If Op = '*' Then
    EmitInstr('IMUL EAX,EBX')
  Else If (Op = '/') Or (Op = 'DIV') Then
  Begin
    EmitInstr('CDQ');
    EmitInstr('IDIV EBX');
  End
  Else If Op = 'MOD' Then
  Begin
    EmitInstr('CDQ');
    EmitInstr('IDIV EBX');
    EmitInstr('MOV EAX,EDX');
  End
  { Decalages }
  Else If Op = 'SHL' Then
  Begin
    EmitInstr('MOV ECX,EBX');
    EmitInstr('SHL EAX,CL');
  End
  Else If Op = 'SHR' Then
  Begin
    EmitInstr('MOV ECX,EBX');
    EmitInstr('SHR EAX,CL');
  End
  { Bit a bit / Logique }
  Else If Op = 'AND' Then
    EmitInstr('AND EAX,EBX')
  Else If Op = 'OR' Then
    EmitInstr('OR EAX,EBX')
  Else If Op = 'XOR' Then
    EmitInstr('XOR EAX,EBX')
  { Comparaisons }
  Else If Op = '=' Then
  Begin
    LblTrue := LabelGen;
    LblEnd  := LabelGen;
    EmitInstr('CMP EAX,EBX');
    EmitInstr('JE ' + LblTrue);
    EmitInstr('XOR EAX,EAX');
    EmitInstr('JMP ' + LblEnd);
    EmitLabel(LblTrue);
    EmitInstr('MOV EAX,1');
    EmitLabel(LblEnd);
  End
  Else If Op = '<>' Then
  Begin
    LblTrue := LabelGen;
    LblEnd  := LabelGen;
    EmitInstr('CMP EAX,EBX');
    EmitInstr('JNE ' + LblTrue);
    EmitInstr('XOR EAX,EAX');
    EmitInstr('JMP ' + LblEnd);
    EmitLabel(LblTrue);
    EmitInstr('MOV EAX,1');
    EmitLabel(LblEnd);
  End
  Else If Op = '<' Then
  Begin
    LblTrue := LabelGen;
    LblEnd  := LabelGen;
    EmitInstr('CMP EAX,EBX');
    EmitInstr('JL ' + LblTrue);
    EmitInstr('XOR EAX,EAX');
    EmitInstr('JMP ' + LblEnd);
    EmitLabel(LblTrue);
    EmitInstr('MOV EAX,1');
    EmitLabel(LblEnd);
  End
  Else If Op = '<=' Then
  Begin
    LblTrue := LabelGen;
    LblEnd  := LabelGen;
    EmitInstr('CMP EAX,EBX');
    EmitInstr('JLE ' + LblTrue);
    EmitInstr('XOR EAX,EAX');
    EmitInstr('JMP ' + LblEnd);
    EmitLabel(LblTrue);
    EmitInstr('MOV EAX,1');
    EmitLabel(LblEnd);
  End
  Else If Op = '>' Then
  Begin
    LblTrue := LabelGen;
    LblEnd  := LabelGen;
    EmitInstr('CMP EAX,EBX');
    EmitInstr('JG ' + LblTrue);
    EmitInstr('XOR EAX,EAX');
    EmitInstr('JMP ' + LblEnd);
    EmitLabel(LblTrue);
    EmitInstr('MOV EAX,1');
    EmitLabel(LblEnd);
  End
  Else If Op = '>=' Then
  Begin
    LblTrue := LabelGen;
    LblEnd  := LabelGen;
    EmitInstr('CMP EAX,EBX');
    EmitInstr('JGE ' + LblTrue);
    EmitInstr('XOR EAX,EAX');
    EmitInstr('JMP ' + LblEnd);
    EmitLabel(LblTrue);
    EmitInstr('MOV EAX,1');
    EmitLabel(LblEnd);
  End
  { IN (ensemble) : BT [set], val }
  Else If Op = 'IN' Then
  Begin
    LblTrue := LabelGen;
    LblEnd  := LabelGen;
    EmitInstr('BT EBX,EAX');
    EmitInstr('JC ' + LblTrue);
    EmitInstr('XOR EAX,EAX');
    EmitInstr('JMP ' + LblEnd);
    EmitLabel(LblTrue);
    EmitInstr('MOV EAX,1');
    EmitLabel(LblEnd);
  End
  Else
    EmitComment('; operateur binaire inconnu: ' + Op);
End;

{ ------------------------------------------------------------ }
{ ParseExprPrec : parseur de Pratt pour expressions Pascal      }
{ MinPrec = niveau de precedence minimal a capturer.            }
{ Le resultat est toujours dans EAX.                            }
{ Gere le court-circuit pour AND et OR booleens.                }
{ ------------------------------------------------------------ }

Procedure ParseExprPrec(PI : Integer; MinPrec : Integer);
Var
  Op       : TString;
  Prec     : Integer;
  LblF     : TString;
  LblE     : TString;
  LeftIsStr : Boolean;
Begin
  ParseUnary(PI);

  While Not EPAtEnd Do
  Begin
    { Lire l operateur courant }
    Op := '';
    If TokenPool[EP].Kind = TK_OP Then
      Op := StrUpperCase(TokenPool[EP].Val)
    Else If TokenPool[EP].Kind = TK_KEYWORD Then
      Op := StrUpperCase(TokenPool[EP].Val);

    Prec := BinOpPrec(Op);
    If (Prec = 0) Or (Prec < MinPrec) Then Break;

    { Detecter si la partie gauche est une chaine }
    LeftIsStr := (LastVarTypeIdx = TY_IDX_STRING) Or
                 (LastVarTypeIdx = TY_IDX_PCHAR);

    Inc(EP); { consommer l operateur }

    { --- Concatenation de chaines avec + (TODO 16) --- }
    If (Op = '+') And LeftIsStr Then
    Begin
      EmitInstr('MOV ESI,EAX');        { ESI = chaine gauche  }
      EmitInstr('LEA EDI,[STRBUF1]');
      EmitInstr('CALL ' + TP_RT_PFX + 'STRCPY');
      ParseExprPrec(PI, Prec + 1);
      EmitInstr('MOV EDI,EAX');        { EDI = chaine droite  }
      EmitInstr('LEA ESI,[STRBUF1]');
      EmitInstr('CALL ' + TP_RT_PFX + 'CONCAT');
      EmitInstr('LEA EAX,[STRBUF1]');
      LastVarTypeIdx := TY_IDX_STRING;
      Continue;
    End;

    { --- Comparaison de chaines (TODO 16) --- }
    If ((Op = '=') Or (Op = '<>') Or (Op = '<') Or (Op = '>') Or
        (Op = '<=') Or (Op = '>=')) And LeftIsStr Then
    Begin
      EmitInstr('PUSH EAX');            { sauver gauche }
      ParseExprPrec(PI, Prec + 1);
      EmitInstr('MOV EDI,EAX');         { EDI = droite  }
      EmitInstr('POP ESI');             { ESI = gauche  }
      EmitInstr('CALL ' + TP_RT_PFX + 'STRCMP');
      { EAX = resultat strcmp: <0, 0, >0 }
      LblF := LabelGen;
      LblE := LabelGen;
      If Op = '=' Then
      Begin
        EmitInstr('TEST EAX,EAX');
        EmitInstr('JZ ' + LblF);
      End
      Else If Op = '<>' Then
      Begin
        EmitInstr('TEST EAX,EAX');
        EmitInstr('JNZ ' + LblF);
      End
      Else If Op = '<' Then
      Begin
        EmitInstr('TEST EAX,EAX');
        EmitInstr('JS ' + LblF);
      End
      Else If Op = '>' Then
      Begin
        EmitInstr('CMP EAX,0');
        EmitInstr('JG ' + LblF);
      End
      Else If Op = '<=' Then
      Begin
        EmitInstr('CMP EAX,0');
        EmitInstr('JLE ' + LblF);
      End
      Else If Op = '>=' Then
      Begin
        EmitInstr('TEST EAX,EAX');
        EmitInstr('JNS ' + LblF);
      End;
      EmitInstr('XOR EAX,EAX');
      EmitInstr('JMP ' + LblE);
      EmitLabel(LblF);
      EmitInstr('MOV EAX,1');
      EmitLabel(LblE);
      LastVarTypeIdx := TY_IDX_BOOLEAN;
      Continue;
    End;

    { --- Court-circuit AND (ET logique) --- }
    If Op = 'AND' Then
    Begin
      LblF := LabelGen;
      LblE := LabelGen;
      EmitInstr('TEST EAX,EAX');
      EmitInstr('JZ ' + LblF);
      ParseExprPrec(PI, Prec + 1);
      EmitInstr('TEST EAX,EAX');
      EmitInstr('JZ ' + LblF);
      EmitInstr('MOV EAX,1');
      EmitInstr('JMP ' + LblE);
      EmitLabel(LblF);
      EmitInstr('XOR EAX,EAX');
      EmitLabel(LblE);
      Continue;
    End;

    { --- Court-circuit OR (OU logique) --- }
    If Op = 'OR' Then
    Begin
      LblF := LabelGen;
      LblE := LabelGen;
      EmitInstr('TEST EAX,EAX');
      EmitInstr('JNZ ' + LblF);
      ParseExprPrec(PI, Prec + 1);
      EmitInstr('TEST EAX,EAX');
      EmitInstr('JNZ ' + LblF);
      EmitInstr('XOR EAX,EAX');
      EmitInstr('JMP ' + LblE);
      EmitLabel(LblF);
      EmitInstr('MOV EAX,1');
      EmitLabel(LblE);
      Continue;
    End;

    { --- Operateurs binaires normaux --- }
    { Sauver la valeur gauche (EAX) sur la pile }
    EmitInstr('PUSH EAX');

    ParseExprPrec(PI, Prec + 1);

    { EAX = droite, pile = gauche }
    EmitInstr('MOV EBX,EAX');
    EmitInstr('POP EAX');
    EmitBinOp(Op);
  End;
End;

{ ------------------------------------------------------------ }
{ ParseExpr : parser une expression complete                    }
{ Appelle ParseExprPrec avec la precedence minimale (1).        }
{ ------------------------------------------------------------ }

Procedure ParseExpr(PI : Integer);
Begin
  ParseExprPrec(PI, 1);
End;

{ ============================================================ }
{ TODO 12 - ENTREES/SORTIES                       [IMPLEMENTE] }
{ ============================================================ }

{ ------------------------------------------------------------ }
{ InferExprType : deviner le type de l expression courante      }
{ en examinant le premier token sans avancer EP.                }
{ Retourne un TY_IDX_* valide.                                 }
{ ------------------------------------------------------------ }

Function InferExprType(PI : Integer) : Integer;
Var
  Up : TString;
  SI, LI : Integer;
Begin
  InferExprType := TY_IDX_INTEGER;
  If EP >= EPEnd Then Exit;

  If TokenPool[EP].Kind = TK_STRING Then
  Begin
    InferExprType := TY_IDX_STRING;
    Exit;
  End;

  If TokenPool[EP].Kind = TK_CHAR Then
  Begin
    InferExprType := TY_IDX_CHAR;
    Exit;
  End;

  If TokenPool[EP].Kind = TK_IDENT Then
  Begin
    Up := StrUpperCase(TokenPool[EP].Val);
    If (Up = 'TRUE') Or (Up = 'FALSE') Then
    Begin
      InferExprType := TY_IDX_BOOLEAN;
      Exit;
    End;

    { Chercher dans les variables locales }
    If PI >= 0 Then
    Begin
      LI := FindLocal(PI, Up);
      If LI >= 0 Then
      Begin
        InferExprType := ProcTab[PI].Locals[LI].TypeIdx;
        Exit;
      End;
      LI := FindParam(PI, Up);
      If LI >= 0 Then
      Begin
        InferExprType := ProcTab[PI].Params[LI].TypeIdx;
        Exit;
      End;
    End;

    { Chercher dans les symboles globaux }
    SI := SymFind(Up);
    If SI >= 0 Then
    Begin
      InferExprType := SymTab[SI].TypeIdx;
      Exit;
    End;
  End;
End;

{ ------------------------------------------------------------ }
{ EmitPrintEAX : emettre le code pour afficher EAX selon le    }
{ type. EAX contient la valeur a afficher.                     }
{ String -> appel de _TPRT_PRINTSTR (EAX=pointeur ASCIIZ)     }
{ Char -> ecriture d un caractere unique via WriteFile          }
{ Boolean -> 'TRUE' ou 'FALSE'                                 }
{ Integer -> conversion en chaine puis affichage               }
{ ------------------------------------------------------------ }

Procedure EmitPrintEAX(TypeIdx : Integer);
Var
  LblFalse, LblDone : TString;
Begin
  If TypeIdx = TY_IDX_STRING Then
  Begin
    { EAX = pointeur ASCIIZ -> afficher directement }
    EmitInstr('MOV ESI,EAX');
    EmitInstr('CALL ' + TP_RT_PFX + 'PRINTSTR');
  End
  Else If TypeIdx = TY_IDX_CHAR Then
  Begin
    { EAX = caractere -> stocker dans STRTMP et afficher }
    EmitInstr('MOV BYTE PTR [STRTMP],AL');
    EmitInstr('MOV BYTE PTR [STRTMP+1],0');
    EmitInstr('LEA ESI,[STRTMP]');
    EmitInstr('CALL ' + TP_RT_PFX + 'PRINTSTR');
  End
  Else If TypeIdx = TY_IDX_BOOLEAN Then
  Begin
    { EAX = 0 -> FALSE, sinon -> TRUE }
    LblFalse := LabelGen;
    LblDone  := LabelGen;
    EmitInstr('TEST EAX,EAX');
    EmitInstr('JZ ' + LblFalse);
    EmitInstr('LEA ESI,[TRUE_STR]');
    EmitInstr('JMP ' + LblDone);
    EmitLabel(LblFalse);
    EmitInstr('LEA ESI,[FALSE_STR]');
    EmitLabel(LblDone);
    EmitInstr('CALL ' + TP_RT_PFX + 'PRINTSTR');
  End
  Else
  Begin
    { Integer / Word / Byte / autre -> convertir en chaine }
    EmitInstr('CALL ' + TP_RT_PFX + 'NUMTOSTR');
    EmitInstr('LEA ESI,[NUMBUF]');
    EmitInstr('CALL ' + TP_RT_PFX + 'PRINTSTR');
  End;
End;

{ ------------------------------------------------------------ }
{ ParseWriteStmt : parser Write(args) ou WriteLn(args).         }
{ EP pointe apres WRITE/WRITELN deja consomme.                 }
{ Gere plusieurs arguments separes par virgule.                }
{ Gere le formatage :width (ignore pour l instant).            }
{ ------------------------------------------------------------ }

Procedure ParseWriteStmt(PI : Integer; IsWriteLn : Boolean);
Var
  TIdx : Integer;
Begin
  If IsWriteLn Then
    EmitComment('writeln')
  Else
    EmitComment('write');

  { Gerer WriteLn sans arguments -> juste CR+LF }
  If EPAtEnd Then
  Begin
    If IsWriteLn Then
    Begin
      EmitInstr('LEA ESI,[CRLF]');
      EmitInstr('CALL ' + TP_RT_PFX + 'PRINTSTR');
    End;
    Exit;
  End;

  { Si pas de parenthese, WriteLn sans args }
  If Not ((TokenPool[EP].Kind = TK_PUNCT) And (TokenPool[EP].Val = '(')) Then
  Begin
    If IsWriteLn Then
    Begin
      EmitInstr('LEA ESI,[CRLF]');
      EmitInstr('CALL ' + TP_RT_PFX + 'PRINTSTR');
    End;
    Exit;
  End;

  { Consommer ( }
  Inc(EP);

  { Boucle sur les arguments }
  While Not EPAtEnd Do
  Begin
    { Fin des arguments ? }
    If (TokenPool[EP].Kind = TK_PUNCT) And (TokenPool[EP].Val = ')') Then
      Break;

    { Determiner le type de l argument }
    TIdx := InferExprType(PI);

    { Evaluer l expression }
    ParseExpr(PI);

    { Detecter formatage :width }
    If Not EPAtEnd Then
    Begin
      If (TokenPool[EP].Kind = TK_PUNCT) And (TokenPool[EP].Val = ':') Then
      Begin
        Inc(EP); { consommer : }
        { Ignorer l expression de largeur }
        If Not EPAtEnd Then
        Begin
          If TokenPool[EP].Kind = TK_INTEGER Then
            Inc(EP)
          Else
            ParseExpr(PI); { evaluer et jeter }
        End;
        { Si :w:d (formatage flottant) : ignorer aussi d }
        If Not EPAtEnd Then
        Begin
          If (TokenPool[EP].Kind = TK_PUNCT) And (TokenPool[EP].Val = ':') Then
          Begin
            Inc(EP);
            If Not EPAtEnd Then
            Begin
              If TokenPool[EP].Kind = TK_INTEGER Then
                Inc(EP)
              Else
                ParseExpr(PI);
            End;
          End;
        End;
      End;
    End;

    { Afficher selon le type }
    EmitPrintEAX(TIdx);

    { Virgule entre arguments }
    If Not EPAtEnd Then
    Begin
      If (TokenPool[EP].Kind = TK_PUNCT) And (TokenPool[EP].Val = ',') Then
        Inc(EP)
      Else
        Break;
    End;
  End;

  { Consommer ) }
  If Not EPAtEnd Then
    If (TokenPool[EP].Kind = TK_PUNCT) And (TokenPool[EP].Val = ')') Then
      Inc(EP);

  { WriteLn : ajouter CR+LF }
  If IsWriteLn Then
  Begin
    EmitInstr('LEA ESI,[CRLF]');
    EmitInstr('CALL ' + TP_RT_PFX + 'PRINTSTR');
  End;
End;

{ ------------------------------------------------------------ }
{ ParseReadStmt : parser Read(vars) ou ReadLn(vars).            }
{ EP pointe apres READ/READLN deja consomme.                   }
{ Lit une ligne depuis STDIN, puis parse les variables.         }
{ ------------------------------------------------------------ }

Procedure ParseReadStmt(PI : Integer; IsReadLn : Boolean);
Var
  VName, Up : TString;
  SI, LI    : Integer;
  TIdx      : Integer;
Begin
  If IsReadLn Then
    EmitComment('readln')
  Else
    EmitComment('read');

  { ReadLn sans arguments : lire et jeter une ligne }
  If EPAtEnd Or
     Not ((TokenPool[EP].Kind = TK_PUNCT) And (TokenPool[EP].Val = '(')) Then
  Begin
    If IsReadLn Then
      EmitInstr('CALL ' + TP_RT_PFX + 'READLN');
    Exit;
  End;

  { Consommer ( }
  Inc(EP);

  { Lire une ligne dans INBUF }
  EmitInstr('CALL ' + TP_RT_PFX + 'READLN');

  { Boucle sur les variables }
  While Not EPAtEnd Do
  Begin
    If (TokenPool[EP].Kind = TK_PUNCT) And (TokenPool[EP].Val = ')') Then
      Break;

    If TokenPool[EP].Kind = TK_IDENT Then
    Begin
      VName := TokenPool[EP].Val;
      Up := StrUpperCase(VName);
      Inc(EP);

      { Determiner le type de la variable }
      TIdx := TY_IDX_INTEGER;
      If PI >= 0 Then
      Begin
        LI := FindLocal(PI, Up);
        If LI >= 0 Then
          TIdx := ProcTab[PI].Locals[LI].TypeIdx
        Else
        Begin
          LI := FindParam(PI, Up);
          If LI >= 0 Then
            TIdx := ProcTab[PI].Params[LI].TypeIdx;
        End;
      End;
      If TIdx = TY_IDX_INTEGER Then
      Begin
        SI := SymFind(Up);
        If SI >= 0 Then
          TIdx := SymTab[SI].TypeIdx;
      End;

      If (TIdx = TY_IDX_STRING) Or (TIdx = TY_IDX_PCHAR) Then
      Begin
        { Copier INBUF vers la variable string }
        EmitInstr('LEA ESI,[INBUF]');
        GenLoadAddr(PI, VName);
        EmitInstr('MOV EDI,EAX');
        { Copier octet par octet jusqu au NUL }
        EmitInstr('CALL ' + TP_RT_PFX + 'STRCPY');
      End
      Else If TIdx = TY_IDX_CHAR Then
      Begin
        { Prendre le premier caractere de INBUF }
        EmitInstr('MOVZX EAX,BYTE PTR [INBUF]');
        GenStoreVar(PI, VName);
      End
      Else
      Begin
        { Integer : convertir INBUF en nombre }
        EmitInstr('LEA ESI,[INBUF]');
        EmitInstr('CALL ' + TP_RT_PFX + 'STRTONUM');
        GenStoreVar(PI, VName);
      End;
    End
    Else
      Inc(EP); { sauter token inconnu }

    { Virgule entre variables }
    If Not EPAtEnd Then
    Begin
      If (TokenPool[EP].Kind = TK_PUNCT) And (TokenPool[EP].Val = ',') Then
        Inc(EP)
      Else
        Break;
    End;
  End;

  { Consommer ) }
  If Not EPAtEnd Then
    If (TokenPool[EP].Kind = TK_PUNCT) And (TokenPool[EP].Val = ')') Then
      Inc(EP);
End;

{ ------------------------------------------------------------ }
{ ParseStrStmt : parser Str(N[:W], S)                          }
{ Convertit un nombre en chaine.                               }
{ ------------------------------------------------------------ }

Procedure ParseStrStmt(PI : Integer);
Var
  VName : TString;
Begin
  EmitComment('str');

  { Consommer ( }
  If Not EPMatch('(') Then Exit;

  { Evaluer l expression numerique }
  ParseExpr(PI);

  { Ignorer le formatage :width }
  If Not EPAtEnd Then
  Begin
    If (TokenPool[EP].Kind = TK_PUNCT) And (TokenPool[EP].Val = ':') Then
    Begin
      Inc(EP);
      If Not EPAtEnd Then
      Begin
        If TokenPool[EP].Kind = TK_INTEGER Then
          Inc(EP)
        Else
          ParseExpr(PI);
      End;
    End;
  End;

  { Convertir en chaine }
  EmitInstr('CALL ' + TP_RT_PFX + 'NUMTOSTR');

  { Consommer , }
  EPMatch(',');

  { Variable cible }
  If Not EPAtEnd Then
  Begin
    If TokenPool[EP].Kind = TK_IDENT Then
    Begin
      VName := TokenPool[EP].Val;
      Inc(EP);

      { Copier NUMBUF vers la variable string }
      EmitInstr('LEA ESI,[NUMBUF]');
      GenLoadAddr(PI, VName);
      EmitInstr('MOV EDI,EAX');
      EmitInstr('CALL ' + TP_RT_PFX + 'STRCPY');
    End;
  End;

  { Consommer ) }
  EPMatch(')');
End;

{ ------------------------------------------------------------ }
{ ParseValStmt : parser Val(S, N, Code)                        }
{ Convertit une chaine en nombre.                              }
{ ------------------------------------------------------------ }

Procedure ParseValStmt(PI : Integer);
Var
  VName : TString;
Begin
  EmitComment('val');

  { Consommer ( }
  If Not EPMatch('(') Then Exit;

  { Evaluer l expression chaine }
  ParseExpr(PI);
  EmitInstr('MOV ESI,EAX');

  { Convertir en nombre }
  EmitInstr('CALL ' + TP_RT_PFX + 'STRTONUM');

  { Consommer , }
  EPMatch(',');

  { Variable numerique cible }
  If Not EPAtEnd Then
  Begin
    If TokenPool[EP].Kind = TK_IDENT Then
    Begin
      VName := TokenPool[EP].Val;
      Inc(EP);
      GenStoreVar(PI, VName);
    End;
  End;

  { Troisieme argument Code : stocker 0 (pas d erreur) }
  If Not EPAtEnd Then
  Begin
    If (TokenPool[EP].Kind = TK_PUNCT) And (TokenPool[EP].Val = ',') Then
    Begin
      Inc(EP);
      If Not EPAtEnd Then
      Begin
        If TokenPool[EP].Kind = TK_IDENT Then
        Begin
          VName := TokenPool[EP].Val;
          Inc(EP);
          EmitInstr('XOR EAX,EAX');
          GenStoreVar(PI, VName);
        End;
      End;
    End;
  End;

  { Consommer ) }
  EPMatch(')');
End;

{ ============================================================ }
{ TODO 13 - STRUCTURES DE CONTROLE                [IMPLEMENTE] }
{ ============================================================ }

{ ------------------------------------------------------------ }
{ LoopPush : empiler un contexte de boucle (Break/Continue)     }
{ ------------------------------------------------------------ }

Procedure LoopPush(Const LblBreak, LblCont : TString);
Begin
  Inc(LoopTop);
  If LoopTop > 31 Then
  Begin
    WarnMsg('trop de boucles imbriquees');
    Dec(LoopTop);
    Exit;
  End;
  LoopBreakLbl[LoopTop] := LblBreak;
  LoopContLbl[LoopTop]  := LblCont;
End;

{ ------------------------------------------------------------ }
{ LoopPop : depiler un contexte de boucle                       }
{ ------------------------------------------------------------ }

Procedure LoopPop;
Begin
  If LoopTop >= 0 Then
    Dec(LoopTop);
End;

{ ------------------------------------------------------------ }
{ ParseIfStmt : parser IF cond THEN stmt [ELSE stmt]           }
{ EP pointe sur IF a l entree.                                  }
{ ------------------------------------------------------------ }

Procedure ParseIfStmt(PI : Integer);
Var
  LblElse  : TString;
  LblEndIf : TString;
  HasElse  : Boolean;
Begin
  EmitComment('if');

  Inc(EP);  { consommer IF }

  { Evaluer la condition }
  ParseExpr(PI);

  LblElse  := LabelGen;
  LblEndIf := LabelGen;

  EmitInstr('TEST EAX,EAX');
  EmitInstr('JZ ' + LblElse);

  { Consommer THEN }
  If Not EPAtEnd Then
    If (TokenPool[EP].Kind = TK_KEYWORD) And
       (StrUpperCase(TokenPool[EP].Val) = 'THEN') Then
      Inc(EP);

  { Parser l instruction du THEN }
  ParseStmt(PI);

  { Detecter ELSE }
  HasElse := False;
  If Not EPAtEnd Then
    If (TokenPool[EP].Kind = TK_KEYWORD) And
       (StrUpperCase(TokenPool[EP].Val) = 'ELSE') Then
      HasElse := True;

  If HasElse Then
  Begin
    EmitInstr('JMP ' + LblEndIf);
    EmitLabel(LblElse);
    Inc(EP);  { consommer ELSE }
    ParseStmt(PI);
    EmitLabel(LblEndIf);
  End
  Else
    EmitLabel(LblElse);
End;

{ ------------------------------------------------------------ }
{ ParseCaseStmt : parser CASE expr OF val: stmt; ... END       }
{ EP pointe sur CASE a l entree.                                }
{ ------------------------------------------------------------ }

Procedure ParseCaseStmt(PI : Integer);
Var
  LblEnd  : TString;
  LblNext : TString;
  LblHit  : TString;
  Up      : TString;
  CaseVal : LongInt;
  RangeHi : LongInt;
Begin
  EmitComment('case');

  Inc(EP);  { consommer CASE }

  { Evaluer l expression selecteur }
  ParseExpr(PI);
  EmitInstr('PUSH EAX');  { sauvegarder le selecteur sur la pile }

  { Consommer OF }
  If Not EPAtEnd Then
    If (TokenPool[EP].Kind = TK_KEYWORD) And
       (StrUpperCase(TokenPool[EP].Val) = 'OF') Then
      Inc(EP);

  LblEnd := LabelGen;

  { Boucle sur les branches du CASE }
  While Not EPAtEnd Do
  Begin
    Up := StrUpperCase(TokenPool[EP].Val);

    { END ou ELSE : sortir de la boucle des branches }
    If (TokenPool[EP].Kind = TK_KEYWORD) And
       ((Up = 'END') Or (Up = 'ELSE') Or (Up = 'OTHERWISE')) Then
      Break;

    { Semicolons isoles : sauter }
    If (TokenPool[EP].Kind = TK_PUNCT) And (TokenPool[EP].Val = ';') Then
    Begin
      Inc(EP);
      Continue;
    End;

    LblNext := LabelGen;
    LblHit  := LabelGen;

    { Analyser les valeurs separees par des virgules }
    While Not EPAtEnd Do
    Begin
      { Detecter ':' (fin des valeurs pour cette branche) }
      If (TokenPool[EP].Kind = TK_PUNCT) And (TokenPool[EP].Val = ':') Then
        Break;

      { Lire la valeur }
      CaseVal := 0;
      If TokenPool[EP].Kind = TK_INTEGER Then
      Begin
        CaseVal := TokenPool[EP].IntVal;
        Inc(EP);
      End
      Else If (TokenPool[EP].Kind = TK_CHAR) And
              (Length(TokenPool[EP].Val) > 0) Then
      Begin
        CaseVal := Ord(TokenPool[EP].Val[1]);
        Inc(EP);
      End
      Else
      Begin
        ParseExpr(PI);
        { Valeur dans EAX, stocker en EBX }
        EmitInstr('MOV EBX,EAX');
        EmitInstr('MOV EAX,DWORD PTR [ESP]');
        EmitInstr('CMP EAX,EBX');
        EmitInstr('JE ' + LblHit);

        If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
           (TokenPool[EP].Val = ',') Then
        Begin
          Inc(EP);
          Continue;
        End
        Else
          Break;
      End;

      { Detecter plage val1..val2 }
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = '..') Then
      Begin
        Inc(EP);  { consommer .. }
        RangeHi := 0;
        If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_INTEGER) Then
        Begin
          RangeHi := TokenPool[EP].IntVal;
          Inc(EP);
        End;
        EmitInstr('MOV EAX,DWORD PTR [ESP]');
        EmitInstr('CMP EAX,' + IntToStr_(CaseVal));
        EmitInstr('JB ' + LblNext);
        EmitInstr('CMP EAX,' + IntToStr_(RangeHi));
        EmitInstr('JBE ' + LblHit);
        EmitInstr('JMP ' + LblNext);
      End
      Else
      Begin
        EmitInstr('MOV EAX,DWORD PTR [ESP]');
        EmitInstr('CMP EAX,' + IntToStr_(CaseVal));
        EmitInstr('JE ' + LblHit);
      End;

      { Virgule : valeurs multiples }
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ',') Then
        Inc(EP)
      Else
        Break;
    End;

    { Aucune valeur ne correspond -> sauter a la branche suivante }
    EmitInstr('JMP ' + LblNext);
    EmitLabel(LblHit);

    { Consommer ':' }
    If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
       (TokenPool[EP].Val = ':') Then
      Inc(EP);

    { Parser l instruction de cette branche }
    ParseStmt(PI);

    { Consommer le ; optionnel }
    If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
       (TokenPool[EP].Val = ';') Then
      Inc(EP);

    { Sauter a la fin du CASE }
    EmitInstr('JMP ' + LblEnd);
    EmitLabel(LblNext);
  End;

  { Gerer la clause ELSE / OTHERWISE }
  If Not EPAtEnd Then
  Begin
    Up := StrUpperCase(TokenPool[EP].Val);
    If (TokenPool[EP].Kind = TK_KEYWORD) And
       ((Up = 'ELSE') Or (Up = 'OTHERWISE')) Then
    Begin
      Inc(EP);
      { Consommer ':' optionnel apres ELSE }
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ':') Then
        Inc(EP);
      EmitComment('case default');
      { Parser les instructions de la clause par defaut jusqu a END }
      While Not EPAtEnd Do
      Begin
        If (TokenPool[EP].Kind = TK_KEYWORD) And
           (StrUpperCase(TokenPool[EP].Val) = 'END') Then
          Break;
        ParseStmt(PI);
        If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
           (TokenPool[EP].Val = ';') Then
          Inc(EP);
      End;
    End;
  End;

  EmitLabel(LblEnd);
  EmitInstr('POP EAX');  { depiler le selecteur }

  { Consommer END }
  If Not EPAtEnd Then
    If (TokenPool[EP].Kind = TK_KEYWORD) And
       (StrUpperCase(TokenPool[EP].Val) = 'END') Then
      Inc(EP);

  { Consommer ; optionnel apres END }
  If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
     (TokenPool[EP].Val = ';') Then
    Inc(EP);
End;

{ ------------------------------------------------------------ }
{ ParseWhileStmt : parser WHILE cond DO stmt                   }
{ EP pointe sur WHILE a l entree.                               }
{ Labels : _TPL_WTEST_N, _TPL_WEND_N                           }
{ ------------------------------------------------------------ }

Procedure ParseWhileStmt(PI : Integer);
Var
  LblTest : TString;
  LblEnd  : TString;
Begin
  EmitComment('while');

  Inc(EP);  { consommer WHILE }

  LblTest := LabelGen;
  LblEnd  := LabelGen;

  { Label de test }
  EmitLabel(LblTest);

  { Evaluer la condition }
  ParseExpr(PI);

  { TEST EAX,EAX / JZ fin }
  EmitInstr('TEST EAX,EAX');
  EmitInstr('JZ ' + LblEnd);

  { Consommer DO }
  If Not EPAtEnd Then
    If (TokenPool[EP].Kind = TK_KEYWORD) And
       (StrUpperCase(TokenPool[EP].Val) = 'DO') Then
      Inc(EP);

  { Empiler le contexte de boucle }
  LoopPush(LblEnd, LblTest);

  { Parser le corps de la boucle }
  ParseStmt(PI);

  { Consommer ; optionnel apres le corps }
  If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
     (TokenPool[EP].Val = ';') Then
    Inc(EP);

  { Retour au test }
  EmitInstr('JMP ' + LblTest);

  { Label fin }
  EmitLabel(LblEnd);

  { Depiler le contexte de boucle }
  LoopPop;
End;

{ ------------------------------------------------------------ }
{ ParseRepeatStmt : parser REPEAT stmts UNTIL cond             }
{ EP pointe sur REPEAT a l entree.                              }
{ Labels : _TPL_RBEG_N, _TPL_REND_N                            }
{ ------------------------------------------------------------ }

Procedure ParseRepeatStmt(PI : Integer);
Var
  LblBeg : TString;
  LblEnd : TString;
Begin
  EmitComment('repeat');

  Inc(EP);  { consommer REPEAT }

  LblBeg := LabelGen;
  LblEnd := LabelGen;

  { Label debut }
  EmitLabel(LblBeg);

  { Empiler le contexte de boucle }
  LoopPush(LblEnd, LblBeg);

  { Parser les instructions jusqu a UNTIL }
  While Not EPAtEnd Do
  Begin
    If (TokenPool[EP].Kind = TK_KEYWORD) And
       (StrUpperCase(TokenPool[EP].Val) = 'UNTIL') Then
      Break;
    ParseStmt(PI);
    If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
       (TokenPool[EP].Val = ';') Then
      Inc(EP);
  End;

  { Consommer UNTIL }
  If Not EPAtEnd Then
    If (TokenPool[EP].Kind = TK_KEYWORD) And
       (StrUpperCase(TokenPool[EP].Val) = 'UNTIL') Then
      Inc(EP);

  { Evaluer la condition }
  ParseExpr(PI);

  { TEST EAX,EAX / JZ debut (si faux, on boucle) }
  EmitInstr('TEST EAX,EAX');
  EmitInstr('JZ ' + LblBeg);

  { Label fin }
  EmitLabel(LblEnd);

  { Depiler le contexte de boucle }
  LoopPop;
End;

{ ------------------------------------------------------------ }
{ ParseForStmt : parser FOR id := lo TO|DOWNTO hi DO stmt      }
{ EP pointe sur FOR a l entree.                                 }
{ Labels : _TPL_FTEST_N, _TPL_FCONT_N, _TPL_FEND_N            }
{ ------------------------------------------------------------ }

Procedure ParseForStmt(PI : Integer);
Var
  VarName  : TString;
  LimLabel : TString;
  LblTest  : TString;
  LblEnd   : TString;
  LblCont  : TString;
  IsDownTo : Boolean;
Begin
  EmitComment('for');

  Inc(EP);  { consommer FOR }

  { Lire la variable de boucle }
  If EPAtEnd Or (TokenPool[EP].Kind <> TK_IDENT) Then Exit;
  VarName := TokenPool[EP].Val;
  Inc(EP);

  { Consommer := }
  If Not EPAtEnd Then
    If (TokenPool[EP].Kind = TK_OP) And (TokenPool[EP].Val = ':=') Then
      Inc(EP);

  { Evaluer l expression de depart }
  ParseExpr(PI);

  { Stocker la valeur de depart dans la variable }
  GenStoreVar(PI, VarName);

  { Detecter TO ou DOWNTO }
  IsDownTo := False;
  If Not EPAtEnd Then
  Begin
    If (TokenPool[EP].Kind = TK_KEYWORD) And
       (StrUpperCase(TokenPool[EP].Val) = 'TO') Then
      Inc(EP)
    Else If (TokenPool[EP].Kind = TK_KEYWORD) And
            (StrUpperCase(TokenPool[EP].Val) = 'DOWNTO') Then
    Begin
      IsDownTo := True;
      Inc(EP);
    End;
  End;

  { Evaluer l expression limite }
  ParseExpr(PI);

  { Stocker la limite dans une variable data temporaire }
  LimLabel := LabelGen;
  EmitInstr('MOV DWORD PTR [' + LimLabel + '],EAX');

  { Generer les labels de boucle }
  LblTest := LabelGen;
  LblEnd  := LabelGen;
  LblCont := LabelGen;

  { Consommer DO }
  If Not EPAtEnd Then
    If (TokenPool[EP].Kind = TK_KEYWORD) And
       (StrUpperCase(TokenPool[EP].Val) = 'DO') Then
      Inc(EP);

  { Label de test }
  EmitLabel(LblTest);

  { Test : CMP variable, limite }
  GenLoadVar(PI, VarName);
  EmitInstr('CMP EAX,DWORD PTR [' + LimLabel + ']');
  If IsDownTo Then
    EmitInstr('JL ' + LblEnd)
  Else
    EmitInstr('JG ' + LblEnd);

  { Empiler le contexte de boucle }
  LoopPush(LblEnd, LblCont);

  { Parser le corps de la boucle }
  ParseStmt(PI);

  { Consommer ; optionnel apres le corps }
  If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
     (TokenPool[EP].Val = ';') Then
    Inc(EP);

  { Label continue (increment) }
  EmitLabel(LblCont);

  { Increment ou decrement de la variable }
  GenLoadVar(PI, VarName);
  If IsDownTo Then
    EmitInstr('DEC EAX')
  Else
    EmitInstr('INC EAX');
  GenStoreVar(PI, VarName);

  { Retour au test }
  EmitInstr('JMP ' + LblTest);

  { Label fin }
  EmitLabel(LblEnd);

  { Depiler le contexte de boucle }
  LoopPop;

  { Ajouter la variable limite dans le segment de donnees }
  DataAddDWord(LimLabel, 0);
End;

{ ------------------------------------------------------------ }
{ ParseGotoStmt : parser GOTO label                            }
{ EP pointe sur GOTO a l entree.                                }
{ ------------------------------------------------------------ }

Procedure ParseGotoStmt(PI : Integer);
Var
  LblName : TString;
Begin
  EmitComment('goto');

  Inc(EP);  { consommer GOTO }

  If Not EPAtEnd Then
  Begin
    { Le label peut etre un nombre ou un identificateur }
    LblName := TokenPool[EP].Val;
    Inc(EP);
    EmitInstr('JMP ' + TP_LBL_PFX + StrUpperCase(LblName));
  End;

  { Consommer ; optionnel }
  If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
     (TokenPool[EP].Val = ';') Then
    Inc(EP);
End;

{ ------------------------------------------------------------ }
{ ParseStmt : parser UNE instruction Pascal.                    }
{ Gere : bloc BEGIN..END, IF, WHILE, REPEAT, FOR, CASE,       }
{ affectation, appel, Write/Read, Exit, Halt, Break, Continue, }
{ GOTO, WITH, labels numeriques.                                }
{ ------------------------------------------------------------ }

Procedure ParseStmt(PI : Integer);
Var
  Up    : TString;
  VName : TString;
  Lbl   : TString;
  SI    : Integer;
  LI    : Integer;
  TIdx    : Integer;
  FOfs    : Integer;
  FSize   : Integer;
  ElemSz  : Integer;
Begin
  If EPAtEnd Then Exit;

  { Point-virgule seul : instruction vide }
  If (TokenPool[EP].Kind = TK_PUNCT) And (TokenPool[EP].Val = ';') Then
  Begin
    Inc(EP);
    Exit;
  End;

  { Point final : fin du programme }
  If (TokenPool[EP].Kind = TK_PUNCT) And (TokenPool[EP].Val = '.') Then
  Begin
    Inc(EP);
    Exit;
  End;

  { Mots-cles }
  If TokenPool[EP].Kind = TK_KEYWORD Then
  Begin
    Up := StrUpperCase(TokenPool[EP].Val);

    { END : ne pas consommer, laisser l appelant gerer }
    If Up = 'END' Then Exit;

    { UNTIL : ne pas consommer, laisser ParseRepeatStmt gerer }
    If Up = 'UNTIL' Then Exit;

    { ELSE : ne pas consommer, laisser ParseIfStmt gerer }
    If Up = 'ELSE' Then Exit;

    { BEGIN : bloc imbrique }
    If Up = 'BEGIN' Then
    Begin
      Inc(EP);  { consommer BEGIN }
      While Not EPAtEnd Do
      Begin
        If (TokenPool[EP].Kind = TK_KEYWORD) And
           (StrUpperCase(TokenPool[EP].Val) = 'END') Then
        Begin
          Inc(EP);  { consommer END }
          { Consommer ; ou . optionnel apres END }
          If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
             ((TokenPool[EP].Val = ';') Or (TokenPool[EP].Val = '.')) Then
            Inc(EP);
          Break;
        End;
        ParseStmt(PI);
        { Consommer ; optionnel entre instructions }
        If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
           (TokenPool[EP].Val = ';') Then
          Inc(EP);
      End;
      Exit;
    End;

    { IF }
    If Up = 'IF' Then Begin ParseIfStmt(PI); Exit; End;

    { WHILE }
    If Up = 'WHILE' Then Begin ParseWhileStmt(PI); Exit; End;

    { REPEAT }
    If Up = 'REPEAT' Then Begin ParseRepeatStmt(PI); Exit; End;

    { FOR }
    If Up = 'FOR' Then Begin ParseForStmt(PI); Exit; End;

    { CASE }
    If Up = 'CASE' Then Begin ParseCaseStmt(PI); Exit; End;

    { GOTO }
    If Up = 'GOTO' Then Begin ParseGotoStmt(PI); Exit; End;

    { WITH : consommer jusqu a DO, puis parser le corps }
    If Up = 'WITH' Then
    Begin
      EmitComment('with');
      Inc(EP);
      While Not EPAtEnd Do
      Begin
        If (TokenPool[EP].Kind = TK_KEYWORD) And
           (StrUpperCase(TokenPool[EP].Val) = 'DO') Then
        Begin
          Inc(EP);
          Break;
        End;
        Inc(EP);
      End;
      ParseStmt(PI);
      Exit;
    End;

    { EXIT : saut au label de retour }
    If Up = 'EXIT' Then
    Begin
      Inc(EP);
      EmitInstr('JMP ' + RetLbl);
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then
        Inc(EP);
      Exit;
    End;

    { HALT : appel ExitProcess }
    If Up = 'HALT' Then
    Begin
      Inc(EP);
      If EPMatch('(') Then
      Begin
        ParseExpr(PI);
        EPMatch(')');
      End
      Else
        EmitInstr('XOR EAX,EAX');
      EmitInstr('PUSH EAX');
      EmitInstr('CALL ExitProcess');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then
        Inc(EP);
      Exit;
    End;

    { BREAK : saut vers fin de boucle englobante }
    If Up = 'BREAK' Then
    Begin
      Inc(EP);
      If LoopTop >= 0 Then
        EmitInstr('JMP ' + LoopBreakLbl[LoopTop])
      Else
        WarnMsg('break en dehors d une boucle');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then
        Inc(EP);
      Exit;
    End;

    { CONTINUE : saut vers test/increment de boucle englobante }
    If Up = 'CONTINUE' Then
    Begin
      Inc(EP);
      If LoopTop >= 0 Then
        EmitInstr('JMP ' + LoopContLbl[LoopTop])
      Else
        WarnMsg('continue en dehors d une boucle');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then
        Inc(EP);
      Exit;
    End;

    { ASM : bloc assembleur inline (TODO 17) }
    If Up = 'ASM' Then
    Begin
      ParseAsmBlock(PI);
      Exit;
    End;

    { LABEL : section de labels, sauter la declaration }
    If Up = 'LABEL' Then
    Begin
      Inc(EP);
      While Not EPAtEnd Do
      Begin
        If (TokenPool[EP].Kind = TK_PUNCT) And (TokenPool[EP].Val = ';') Then
        Begin
          Inc(EP);
          Break;
        End;
        Inc(EP);
      End;
      Exit;
    End;

    { VAR, CONST, TYPE locaux : avancer sans gerer pour l instant }
    If (Up = 'VAR') Or (Up = 'CONST') Or (Up = 'TYPE') Then
    Begin
      Inc(EP);
      Exit;
    End;

    { INC/DEC/NEW/DISPOSE comme keywords }
    If (Up = 'INC') Or (Up = 'DEC') Or (Up = 'NEW') Or
       (Up = 'DISPOSE') Then
    Begin
      ParseExpr(PI);
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then
        Inc(EP);
      Exit;
    End;

    { Autres mots-cles : avancer }
    Inc(EP);
    Exit;
  End;

  { Entier suivi de ':' = label numerique }
  If (TokenPool[EP].Kind = TK_INTEGER) Then
  Begin
    If (EP + 1 < EPEnd) And
       (TokenPool[EP + 1].Kind = TK_PUNCT) And
       (TokenPool[EP + 1].Val = ':') Then
    Begin
      EmitLabel(TP_LBL_PFX + TokenPool[EP].Val);
      Inc(EP, 2);  { consommer nombre et ':' }
      Exit;
    End;
  End;

  { Identificateur }
  If TokenPool[EP].Kind = TK_IDENT Then
  Begin
    VName := TokenPool[EP].Val;
    Up := StrUpperCase(VName);

    { Label identificateur : ident suivi de ':' (pas ':=') }
    If (EP + 1 < EPEnd) And
       (TokenPool[EP + 1].Kind = TK_PUNCT) And
       (TokenPool[EP + 1].Val = ':') And
       Not ((EP + 2 < EPEnd) And (TokenPool[EP + 2].Val = '=')) Then
    Begin
      EmitLabel(TP_LBL_PFX + Up);
      Inc(EP, 2);  { consommer ident et ':' }
      Exit;
    End;

    { INC/DEC/NEW/DISPOSE }
    If (Up = 'INC') Or (Up = 'DEC') Or (Up = 'NEW') Or
       (Up = 'DISPOSE') Then
    Begin
      ParseExpr(PI);
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then
        Inc(EP);
      Exit;
    End;

    { Write / WriteLn }
    If (Up = 'WRITE') Or (Up = 'WRITELN') Then
    Begin
      Inc(EP);
      ParseWriteStmt(PI, Up = 'WRITELN');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then
        Inc(EP);
      Exit;
    End;

    { Read / ReadLn }
    If (Up = 'READ') Or (Up = 'READLN') Then
    Begin
      Inc(EP);
      ParseReadStmt(PI, Up = 'READLN');
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then
        Inc(EP);
      Exit;
    End;

    { Str }
    If Up = 'STR' Then
    Begin
      Inc(EP);
      ParseStrStmt(PI);
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then
        Inc(EP);
      Exit;
    End;

    { Val }
    If Up = 'VAL' Then
    Begin
      Inc(EP);
      ParseValStmt(PI);
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then
        Inc(EP);
      Exit;
    End;

    { DELETE(S, Pos, Len) }
    If Up = 'DELETE' Then
    Begin
      Inc(EP);
      EmitComment('delete');
      If EPMatch('(') Then
      Begin
        { S -> adresse du buffer }
        If Not EPAtEnd Then
        Begin
          Lbl := TokenPool[EP].Val;
          Inc(EP);
          GenLoadAddr(PI, Lbl);
          EmitInstr('PUSH EAX');
        End;
        EPMatch(',');
        { Pos }
        ParseExpr(PI);
        EmitInstr('PUSH EAX');
        EPMatch(',');
        { Len }
        ParseExpr(PI);
        EmitInstr('MOV ECX,EAX');
        EmitInstr('POP EBX');      { Pos }
        EmitInstr('POP ESI');      { S   }
        EmitInstr('CALL ' + TP_RT_PFX + 'DELETE');
        EPMatch(')');
      End;
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then
        Inc(EP);
      Exit;
    End;

    { INSERT(Src, Dst, Pos) }
    If Up = 'INSERT' Then
    Begin
      Inc(EP);
      EmitComment('insert');
      If EPMatch('(') Then
      Begin
        { Src }
        ParseExpr(PI);
        EmitInstr('PUSH EAX');
        EPMatch(',');
        { Dst -> adresse du buffer }
        If Not EPAtEnd Then
        Begin
          Lbl := TokenPool[EP].Val;
          Inc(EP);
          GenLoadAddr(PI, Lbl);
          EmitInstr('PUSH EAX');
        End;
        EPMatch(',');
        { Pos }
        ParseExpr(PI);
        EmitInstr('MOV EBX,EAX');
        EmitInstr('POP EDI');      { Dst }
        EmitInstr('POP ESI');      { Src }
        EmitInstr('CALL ' + TP_RT_PFX + 'INSERT');
        EPMatch(')');
      End;
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then
        Inc(EP);
      Exit;
    End;

    { Appel de proc (dans SymTab) }
    SI := SymFind(Up);
    If (SI >= 0) And (SymTab[SI].Kind = SK_PROC) Then
    Begin
      Inc(EP);
      ParseFuncCall(PI, Up);
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then
        Inc(EP);
      Exit;
    End;

    { Appel de proc (dans ProcTab) }
    LI := 0;
    While LI < ProcCount Do
    Begin
      If ProcTab[LI].Name = Up Then Break;
      Inc(LI);
    End;
    If (LI < ProcCount) And (Not ProcTab[LI].IsFunction) Then
    Begin
      Inc(EP);
      ParseFuncCall(PI, Up);
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ';') Then
        Inc(EP);
      Exit;
    End;

    { Affectation ou appel de fonction }
    Inc(EP);
    If Not EPAtEnd Then
    Begin
      { Affectation tableau : ident[index] := expr }
      If (TokenPool[EP].Kind = TK_PUNCT) And (TokenPool[EP].Val = '[') Then
      Begin
        Inc(EP);
        LastVarTypeIdx := GetVarTypeIdx(PI, VName);
        TIdx := LastVarTypeIdx;        { sauvegarder le type du tableau }
        { Calculer l adresse de l element }
        GenLoadAddr(PI, VName);
        EmitInstr('PUSH EAX');         { sauvegarder adresse base }
        ParseExpr(PI);                 { EAX = index }
        LastVarTypeIdx := TIdx;        { restaurer le type du tableau }
        { Soustraire borne inferieure }
        If (LastVarTypeIdx >= 0) And (LastVarTypeIdx < TypeCount) And
           (TypeTab[LastVarTypeIdx].Kind = TYK_ARRAY) And
           (TypeTab[LastVarTypeIdx].Lo <> 0) Then
          EmitInstr('SUB EAX,' + IntToStr_(TypeTab[LastVarTypeIdx].Lo));
        { Multiplier par la taille de l element }
        If (LastVarTypeIdx >= 0) And (LastVarTypeIdx < TypeCount) And
           (TypeTab[LastVarTypeIdx].Kind = TYK_ARRAY) And
           (TypeTab[LastVarTypeIdx].BaseTypeIdx >= 0) Then
        Begin
          ElemSz := TypeSizeofIdx(TypeTab[LastVarTypeIdx].BaseTypeIdx);
          If ElemSz = 1 Then
            { rien }
          Else If ElemSz = 2 Then
            EmitInstr('SHL EAX,1')
          Else If ElemSz = 4 Then
            EmitInstr('SHL EAX,2')
          Else If ElemSz = 8 Then
            EmitInstr('SHL EAX,3')
          Else
            EmitInstr('IMUL EAX,' + IntToStr_(ElemSz));
        End
        Else
          EmitInstr('SHL EAX,2');
        EmitInstr('POP EBX');
        EmitInstr('ADD EBX,EAX');
        EmitInstr('PUSH EBX');         { sauvegarder adresse element }
        EPMatch(']');
        { Attendre ':=' }
        If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_OP) And
           (TokenPool[EP].Val = ':=') Then
        Begin
          Inc(EP);
          ParseExpr(PI);               { EAX = valeur }
          EmitInstr('POP EBX');
          { Stocker selon la taille de l element }
          If (TIdx >= 0) And (TIdx < TypeCount) And
             (TypeTab[TIdx].Kind = TYK_ARRAY) And
             (TypeTab[TIdx].BaseTypeIdx >= 0) And
             (TypeSizeofIdx(TypeTab[TIdx].BaseTypeIdx) = 1) Then
            EmitInstr('MOV BYTE PTR [EBX],AL')
          Else
            EmitInstr('MOV [EBX],EAX');
        End;
        If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
           (TokenPool[EP].Val = ';') Then
          Inc(EP);
        Exit;
      End;

      { Affectation champ : ident.field := expr }
      If (TokenPool[EP].Kind = TK_PUNCT) And (TokenPool[EP].Val = '.') Then
      Begin
        Inc(EP);
        If Not EPAtEnd Then
        Begin
          Up := StrUpperCase(TokenPool[EP].Val);
          Inc(EP);
          LastVarTypeIdx := GetVarTypeIdx(PI, VName);
          FSize := 4;
          FOfs := FindFieldOffset(LastVarTypeIdx, Up, FSize);
          If FOfs >= 0 Then
          Begin
            GenLoadAddr(PI, VName);
            If FOfs > 0 Then
              EmitInstr('ADD EAX,' + IntToStr_(FOfs));
            EmitInstr('PUSH EAX');     { sauvegarder adresse champ }
            { Attendre ':=' }
            If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_OP) And
               (TokenPool[EP].Val = ':=') Then
            Begin
              Inc(EP);
              ParseExpr(PI);           { EAX = valeur }
              EmitInstr('POP EBX');
              If FSize = 1 Then
                EmitInstr('MOV BYTE PTR [EBX],AL')
              Else
                EmitInstr('MOV [EBX],EAX');
            End;
          End;
        End;
        If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
           (TokenPool[EP].Val = ';') Then
          Inc(EP);
        Exit;
      End;

      { Affectation ident := expr }
      If (TokenPool[EP].Kind = TK_OP) And (TokenPool[EP].Val = ':=') Then
      Begin
        Inc(EP);
        ParseExpr(PI);
        GenStoreVar(PI, VName);
        If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
           (TokenPool[EP].Val = ';') Then
          Inc(EP);
        Exit;
      End;

      { Appel de fonction (via SymTab) }
      If (SI >= 0) And (SymTab[SI].Kind = SK_FUNC) Then
      Begin
        ParseFuncCall(PI, Up);
        If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
           (TokenPool[EP].Val = ';') Then
          Inc(EP);
        Exit;
      End;

      { Appel avec parentheses }
      If (TokenPool[EP].Kind = TK_PUNCT) And (TokenPool[EP].Val = '(') Then
      Begin
        ParseFuncCall(PI, Up);
        If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
           (TokenPool[EP].Val = ';') Then
          Inc(EP);
        Exit;
      End;
    End;

    { Sinon : continuer }
    Exit;
  End;

  { Autre : avancer }
  Inc(EP);
End;
{ Gere : affectation, appel, EXIT, var := expr, INC, DEC       }
{ Utilise ParseStmt pour chaque instruction.                    }
{ ------------------------------------------------------------ }

Procedure ParseBody(PI : Integer);
Var
  Up      : TString;
  SaveEP, SaveEnd : Integer;
Begin
  { Sauvegarder le contexte si necessaire }
  SaveEP  := EP;
  SaveEnd := EPEnd;

  If PI >= 0 Then
  Begin
    EP    := ProcTab[PI].BodyStart;
    EPEnd := ProcTab[PI].BodyEnd;
    CurProcIdx := PI;
  End;

  { Initialiser la pile de boucles }
  LoopTop := -1;

  { Sauter le BEGIN initial }
  If Not EPAtEnd Then
  Begin
    Up := StrUpperCase(TokenPool[EP].Val);
    If Up = 'BEGIN' Then
      Inc(EP);
  End;

  { Parser les instructions du corps via ParseStmt }
  While Not EPAtEnd Do
  Begin
    { END : fin du bloc }
    If (TokenPool[EP].Kind = TK_KEYWORD) And
       (StrUpperCase(TokenPool[EP].Val) = 'END') Then
    Begin
      Inc(EP);
      { Sauter le '.' ou ';' apres END }
      If Not EPAtEnd Then
      Begin
        If (TokenPool[EP].Kind = TK_PUNCT) And
           ((TokenPool[EP].Val = '.') Or (TokenPool[EP].Val = ';')) Then
          Inc(EP);
      End;
      Break;
    End;

    { Point final : fin du programme }
    If (TokenPool[EP].Kind = TK_PUNCT) And (TokenPool[EP].Val = '.') Then
    Begin
      Inc(EP);
      Break;
    End;

    { Deleguer a ParseStmt }
    ParseStmt(PI);
  End;

  { Restaurer le contexte }
  EP    := SaveEP;
  EPEnd := SaveEnd;
End;

{ ------------------------------------------------------------ }
{ EmitProcedures : emettre le code ASM pour chaque procedure   }
{ et fonction declaree dans ProcTab.                            }
{ Emet le prologue, le corps (ParseBody), et l epilogue.       }
{ ------------------------------------------------------------ }

Procedure EmitProcedures;
Var
  FI       : Integer;
Begin
  For FI := 0 To ProcCount - 1 Do
  Begin
    If ProcTab[FI].IsForward Then Continue;
    If ProcTab[FI].IsExternal Then Continue;

    EmitBlankLine;
    EmitComment('--- ' + ProcTab[FI].Name + ' ---');
    EmitLabel(ProcTab[FI].MangledName);
    EmitProlog(ProcTab[FI].LocalSize);

    { Initialiser la valeur de retour a 0 pour les fonctions }
    If ProcTab[FI].IsFunction Then
      EmitInstr('MOV DWORD PTR ' + EBPOfs(ProcTab[FI].RetOffset) + ',0');

    { Label de retour }
    RetLbl := LabelGen;

    { Parser et emettre le corps de la fonction }
    ParseBody(FI);

    { Emettre le label de retour }
    EmitLabel(RetLbl);

    { Charger la valeur de retour dans EAX pour les fonctions }
    If ProcTab[FI].IsFunction Then
      EmitInstr('MOV EAX,' + 'DWORD PTR ' +
        EBPOfs(ProcTab[FI].RetOffset));

    EmitEpilog;
  End;
End;

{ ============================================================ }
{ TODO 17 - INSTRUCTION ASM ET TRADUCTION 8086 -> 80386        }
{           [IMPLEMENTE]                                        }
{ ============================================================ }

{ ------------------------------------------------------------ }
{ TranslateReg16to32 : traduire un registre 8086 (16 bits)     }
{ vers son equivalent 80386 (32 bits).                          }
{ AX->EAX, BX->EBX, CX->ECX, DX->EDX                          }
{ SI->ESI, DI->EDI, BP->EBP, SP->ESP                           }
{ Registres 8 bits (AL,AH,BL,...) : inchanges                  }
{ Registres de segment (CS,DS,ES,SS) : retourne '' (ignores)   }
{ ------------------------------------------------------------ }

Function TranslateReg16to32(Const Reg : TString) : TString;
Var
  Up : TString;
Begin
  Up := StrUpperCase(Reg);
  { Registres 16 bits -> 32 bits }
  If Up = 'AX' Then TranslateReg16to32 := 'EAX'
  Else If Up = 'BX' Then TranslateReg16to32 := 'EBX'
  Else If Up = 'CX' Then TranslateReg16to32 := 'ECX'
  Else If Up = 'DX' Then TranslateReg16to32 := 'EDX'
  Else If Up = 'SI' Then TranslateReg16to32 := 'ESI'
  Else If Up = 'DI' Then TranslateReg16to32 := 'EDI'
  Else If Up = 'BP' Then TranslateReg16to32 := 'EBP'
  Else If Up = 'SP' Then TranslateReg16to32 := 'ESP'
  { Registres de segment : ignores en mode FLAT Win32 }
  Else If Up = 'CS' Then TranslateReg16to32 := ''
  Else If Up = 'DS' Then TranslateReg16to32 := ''
  Else If Up = 'ES' Then TranslateReg16to32 := ''
  Else If Up = 'SS' Then TranslateReg16to32 := ''
  { Registres 8 bits : inchanges }
  Else If (Up = 'AL') Or (Up = 'AH') Or (Up = 'BL') Or (Up = 'BH') Or
          (Up = 'CL') Or (Up = 'CH') Or (Up = 'DL') Or (Up = 'DH') Then
    TranslateReg16to32 := Up
  { Registres 32 bits deja : inchanges }
  Else If (Up = 'EAX') Or (Up = 'EBX') Or (Up = 'ECX') Or (Up = 'EDX') Or
          (Up = 'ESI') Or (Up = 'EDI') Or (Up = 'EBP') Or (Up = 'ESP') Then
    TranslateReg16to32 := Up
  Else
    TranslateReg16to32 := Reg;  { pas un registre, retourner tel quel }
End;

{ ------------------------------------------------------------ }
{ IsAsmReg : tester si un identificateur est un registre x86   }
{ ------------------------------------------------------------ }

Function IsAsmReg(Const S : TString) : Boolean;
Var
  Up : TString;
Begin
  Up := StrUpperCase(S);
  IsAsmReg :=
    (Up = 'AX') Or (Up = 'BX') Or (Up = 'CX') Or (Up = 'DX') Or
    (Up = 'SI') Or (Up = 'DI') Or (Up = 'BP') Or (Up = 'SP') Or
    (Up = 'AL') Or (Up = 'AH') Or (Up = 'BL') Or (Up = 'BH') Or
    (Up = 'CL') Or (Up = 'CH') Or (Up = 'DL') Or (Up = 'DH') Or
    (Up = 'EAX') Or (Up = 'EBX') Or (Up = 'ECX') Or (Up = 'EDX') Or
    (Up = 'ESI') Or (Up = 'EDI') Or (Up = 'EBP') Or (Up = 'ESP') Or
    (Up = 'CS') Or (Up = 'DS') Or (Up = 'ES') Or (Up = 'SS');
End;

{ ------------------------------------------------------------ }
{ TranslateAsmOperand : traduire un operande ASM 8086 vers     }
{ 80386. Gere les registres, les immediats, et les references   }
{ memoire avec adressage indirect [BX+SI+disp] etc.            }
{ ------------------------------------------------------------ }

Function TranslateAsmOperand(PI : Integer; Const Op : TString) : TString;
Var
  R     : TString;
  I     : Integer;
  C     : Char;
  Tok   : TString;
  Up    : TString;
Begin
  If Length(Op) = 0 Then
  Begin
    TranslateAsmOperand := '';
    Exit;
  End;

  { Si l operande est un simple registre }
  Up := StrUpperCase(Op);
  If IsAsmReg(Up) Then
  Begin
    TranslateAsmOperand := TranslateReg16to32(Op);
    Exit;
  End;

  { Si c est un reference memoire [xxx] }
  If (Op[1] = '[') And (Op[Length(Op)] = ']') Then
  Begin
    R := '[';
    I := 2;
    While I < Length(Op) Do
    Begin
      C := Op[I];
      { Extraire un token (ident ou autre) }
      If ((C >= 'A') And (C <= 'Z')) Or ((C >= 'a') And (C <= 'z')) Or
         (C = '_') Then
      Begin
        Tok := '';
        While (I < Length(Op)) And
              (((Op[I] >= 'A') And (Op[I] <= 'Z')) Or
               ((Op[I] >= 'a') And (Op[I] <= 'z')) Or
               ((Op[I] >= '0') And (Op[I] <= '9')) Or
               (Op[I] = '_')) Do
        Begin
          Tok := Tok + Op[I];
          Inc(I);
        End;
        { Traduire les registres dans les crochets }
        If IsAsmReg(Tok) Then
          R := R + TranslateReg16to32(Tok)
        Else
        Begin
          { Verifier si c est une variable Pascal }
          If (PI >= 0) And (FindLocal(PI, Tok) >= 0) Then
            R := R + GenVarAddr(PI, Tok)
          Else If (PI >= 0) And (FindParam(PI, Tok) >= 0) Then
            R := R + GenVarAddr(PI, Tok)
          Else If SymFind(StrUpperCase(Tok)) >= 0 Then
            R := R + GenVarAddr(PI, Tok)
          Else
            R := R + Tok;
        End;
      End
      Else
      Begin
        R := R + C;
        Inc(I);
      End;
    End;
    R := R + ']';
    TranslateAsmOperand := R;
    Exit;
  End;

  { Verifier si c est une variable Pascal (pas un immediat) }
  If ((Op[1] >= 'A') And (Op[1] <= 'Z')) Or
     ((Op[1] >= 'a') And (Op[1] <= 'z')) Or
     (Op[1] = '_') Then
  Begin
    If IsAsmReg(Op) Then
    Begin
      TranslateAsmOperand := TranslateReg16to32(Op);
      Exit;
    End;
    { Verifier si c est une variable Pascal connue }
    If (PI >= 0) And (FindLocal(PI, Op) >= 0) Then
    Begin
      TranslateAsmOperand := GenVarRef(PI, Op);
      Exit;
    End;
    If (PI >= 0) And (FindParam(PI, Op) >= 0) Then
    Begin
      TranslateAsmOperand := GenVarRef(PI, Op);
      Exit;
    End;
    If SymFind(StrUpperCase(Op)) >= 0 Then
    Begin
      TranslateAsmOperand := GenVarRef(PI, Op);
      Exit;
    End;
  End;

  { Sinon retourner tel quel (immediat, label, etc.) }
  TranslateAsmOperand := Op;
End;

{ ------------------------------------------------------------ }
{ AsmTrimSpaces : supprimer les espaces en debut et fin         }
{ ------------------------------------------------------------ }

Function AsmTrimSpaces(Const S : TString) : TString;
Var
  A, B : Integer;
Begin
  A := 1;
  While (A <= Length(S)) And (S[A] = ' ') Do Inc(A);
  B := Length(S);
  While (B >= A) And (S[B] = ' ') Do Dec(B);
  AsmTrimSpaces := Copy(S, A, B - A + 1);
End;

{ ------------------------------------------------------------ }
{ TranslateAsmLine : traduire une ligne ASM complete 8086       }
{ vers son equivalent 80386.                                    }
{ Gere : traduction des mnemoniques, registres et adressage     }
{ CBW->CWDE, CWD->CDQ, PUSHF->PUSHFD, POPF->POPFD             }
{ LDS/LES -> MOV registre 32 bits                               }
{ INT nn -> commentaire (emulation future TODO 21)              }
{ IN/OUT -> commentaire (emulation future TODO 22)              }
{ LOOP/LOOPZ/LOOPNZ -> DEC ECX + Jcc equivalent                }
{ ------------------------------------------------------------ }

Procedure TranslateAsmLine(PI : Integer; Const Line : TString);
Var
  S      : TString;
  Mne    : TString;
  Rest   : TString;
  Op1    : TString;
  Op2    : TString;
  I, J   : Integer;
  Depth  : Integer;
  Up     : TString;
  LblEnd : TString;
Begin
  S := AsmTrimSpaces(Line);
  If Length(S) = 0 Then Exit;

  { Extraire le mnemonique (premier mot) }
  I := 1;
  While (I <= Length(S)) And (S[I] <> ' ') And (S[I] <> #9) Do Inc(I);
  Mne := Copy(S, 1, I - 1);
  Up := StrUpperCase(Mne);

  { Extraire le reste (operandes) }
  While (I <= Length(S)) And ((S[I] = ' ') Or (S[I] = #9)) Do Inc(I);
  Rest := Copy(S, I, Length(S) - I + 1);

  { Separer les operandes par virgule (en respectant les crochets) }
  Op1 := '';
  Op2 := '';
  Depth := 0;
  J := 0;
  For I := 1 To Length(Rest) Do
  Begin
    If Rest[I] = '[' Then Inc(Depth)
    Else If Rest[I] = ']' Then Dec(Depth);
    If (Rest[I] = ',') And (Depth = 0) And (J = 0) Then
    Begin
      J := I;
    End;
  End;
  If J > 0 Then
  Begin
    Op1 := AsmTrimSpaces(Copy(Rest, 1, J - 1));
    Op2 := AsmTrimSpaces(Copy(Rest, J + 1, Length(Rest) - J));
  End
  Else
    Op1 := AsmTrimSpaces(Rest);

  { --- Traductions speciales de mnemoniques --- }

  { CBW -> CWDE (extension de signe 8 -> 32 bits via EAX) }
  If Up = 'CBW' Then
  Begin
    EmitInstr('CWDE');
    Exit;
  End;

  { CWD -> CDQ (extension de signe 16 -> 64 bits via EDX:EAX) }
  If Up = 'CWD' Then
  Begin
    EmitInstr('CDQ');
    Exit;
  End;

  { PUSHF -> PUSHFD }
  If Up = 'PUSHF' Then
  Begin
    EmitInstr('PUSHFD');
    Exit;
  End;

  { POPF -> POPFD }
  If Up = 'POPF' Then
  Begin
    EmitInstr('POPFD');
    Exit;
  End;

  { LDS reg, [mem] -> MOV Ereg, DWORD PTR [mem] }
  If Up = 'LDS' Then
  Begin
    EmitComment('LDS traduit en MOV 32 bits (mode FLAT)');
    EmitInstr('MOV ' + TranslateAsmOperand(PI, Op1) + ',' +
              TranslateAsmOperand(PI, Op2));
    Exit;
  End;

  { LES reg, [mem] -> MOV Ereg, DWORD PTR [mem] }
  If Up = 'LES' Then
  Begin
    EmitComment('LES traduit en MOV 32 bits (mode FLAT)');
    EmitInstr('MOV ' + TranslateAsmOperand(PI, Op1) + ',' +
              TranslateAsmOperand(PI, Op2));
    Exit;
  End;

  { LOOP label -> DEC ECX / JNZ label }
  If Up = 'LOOP' Then
  Begin
    EmitInstr('DEC ECX');
    EmitInstr('JNZ ' + TranslateAsmOperand(PI, Op1));
    Exit;
  End;

  { LOOPZ/LOOPE label -> DEC ECX / JNZ +skip / JZ label }
  If (Up = 'LOOPZ') Or (Up = 'LOOPE') Then
  Begin
    LblEnd := LabelGen;
    EmitInstr('DEC ECX');
    EmitInstr('JZ ' + LblEnd);
    EmitInstr('JZ ' + TranslateAsmOperand(PI, Op1));
    EmitLabel(LblEnd);
    Exit;
  End;

  { LOOPNZ/LOOPNE label -> DEC ECX / JZ +skip / JNZ label }
  If (Up = 'LOOPNZ') Or (Up = 'LOOPNE') Then
  Begin
    LblEnd := LabelGen;
    EmitInstr('DEC ECX');
    EmitInstr('JZ ' + LblEnd);
    EmitInstr('JNZ ' + TranslateAsmOperand(PI, Op1));
    EmitLabel(LblEnd);
    Exit;
  End;

  { INT nn -> emulation future (commentaire) }
  If Up = 'INT' Then
  Begin
    EmitComment('INT ' + Op1 + ' (emule - voir TODO 21)');
    EmitInstr('NOP');
    Exit;
  End;

  { IN -> emulation future (commentaire) }
  If Up = 'IN' Then
  Begin
    EmitComment('IN ' + Op1 + ',' + Op2 + ' (emule - voir TODO 22)');
    EmitInstr('NOP');
    Exit;
  End;

  { OUT -> emulation future (commentaire) }
  If Up = 'OUT' Then
  Begin
    EmitComment('OUT ' + Op1 + ',' + Op2 + ' (emule - voir TODO 22)');
    EmitInstr('NOP');
    Exit;
  End;

  { REP MOVSB / REP MOVSW -> REP MOVSD (ou traduire) }
  If Up = 'REP' Then
  Begin
    { Le reste contient l instruction repetee }
    If StrUpperCase(Op1) = 'MOVSW' Then
      EmitInstr('REP MOVSD')
    Else If StrUpperCase(Op1) = 'STOSW' Then
      EmitInstr('REP STOSD')
    Else
      EmitInstr('REP ' + StrUpperCase(Op1));
    Exit;
  End;

  { Instructions sans operande }
  If (Up = 'NOP') Or (Up = 'CLD') Or (Up = 'STD') Or
     (Up = 'RET') Or (Up = 'RETF') Or (Up = 'CLI') Or (Up = 'STI') Or
     (Up = 'MOVSB') Or (Up = 'MOVSW') Or (Up = 'MOVSD') Or
     (Up = 'STOSB') Or (Up = 'STOSW') Or (Up = 'STOSD') Or
     (Up = 'LODSB') Or (Up = 'LODSW') Or (Up = 'LODSD') Or
     (Up = 'SCASB') Or (Up = 'SCASW') Or (Up = 'SCASD') Or
     (Up = 'CMPSB') Or (Up = 'CMPSW') Or (Up = 'CMPSD') Or
     (Up = 'PUSHA') Or (Up = 'POPA') Or
     (Up = 'PUSHAD') Or (Up = 'POPAD') Or
     (Up = 'PUSHFD') Or (Up = 'POPFD') Or
     (Up = 'CWDE') Or (Up = 'CDQ') Or
     (Up = 'SAHF') Or (Up = 'LAHF') Or
     (Up = 'IRET') Or (Up = 'IRETD') Then
  Begin
    { MOVSW -> MOVSD en 32 bits }
    If Up = 'MOVSW' Then EmitInstr('MOVSD')
    Else If Up = 'STOSW' Then EmitInstr('STOSD')
    Else If Up = 'LODSW' Then EmitInstr('LODSD')
    Else If Up = 'SCASW' Then EmitInstr('SCASD')
    Else If Up = 'CMPSW' Then EmitInstr('CMPSD')
    Else If Up = 'PUSHA' Then EmitInstr('PUSHAD')
    Else If Up = 'POPA' Then EmitInstr('POPAD')
    Else If Up = 'IRET' Then EmitInstr('IRETD')
    Else If Up = 'RETF' Then EmitInstr('RET')
    Else EmitInstr(Up);
    Exit;
  End;

  { Instructions avec 1 operande : PUSH, POP, INC, DEC, NEG, NOT, }
  { CALL, JMP, Jcc, MUL, DIV, IMUL, IDIV                          }
  If (Up = 'PUSH') Or (Up = 'POP') Or (Up = 'INC') Or (Up = 'DEC') Or
     (Up = 'NEG') Or (Up = 'NOT') Or (Up = 'CALL') Or (Up = 'JMP') Or
     (Up = 'MUL') Or (Up = 'DIV') Or (Up = 'IMUL') Or (Up = 'IDIV') Or
     (Up = 'JE') Or (Up = 'JNE') Or (Up = 'JZ') Or (Up = 'JNZ') Or
     (Up = 'JL') Or (Up = 'JLE') Or (Up = 'JG') Or (Up = 'JGE') Or
     (Up = 'JB') Or (Up = 'JBE') Or (Up = 'JA') Or (Up = 'JAE') Or
     (Up = 'JC') Or (Up = 'JNC') Or (Up = 'JS') Or (Up = 'JNS') Or
     (Up = 'JO') Or (Up = 'JNO') Or (Up = 'JP') Or (Up = 'JNP') Or
     (Up = 'JCXZ') Or (Up = 'JECXZ') Or
     (Up = 'SETE') Or (Up = 'SETNE') Or (Up = 'SETL') Or
     (Up = 'SETLE') Or (Up = 'SETG') Or (Up = 'SETGE') Or
     (Up = 'SETB') Or (Up = 'SETBE') Or (Up = 'SETA') Or (Up = 'SETAE') Then
  Begin
    { JCXZ -> JECXZ en 32 bits }
    If Up = 'JCXZ' Then
      EmitInstr('JECXZ ' + TranslateAsmOperand(PI, Op1))
    Else If Length(Op2) > 0 Then
      EmitInstr(Up + ' ' + TranslateAsmOperand(PI, Op1) + ',' +
                TranslateAsmOperand(PI, Op2))
    Else
      EmitInstr(Up + ' ' + TranslateAsmOperand(PI, Op1));
    Exit;
  End;

  { Instructions avec 2 operandes : MOV, ADD, SUB, CMP, TEST, AND, }
  { OR, XOR, SHL, SHR, ROL, ROR, RCL, RCR, LEA, XCHG, ADC, SBB   }
  If (Up = 'MOV') Or (Up = 'ADD') Or (Up = 'SUB') Or (Up = 'CMP') Or
     (Up = 'TEST') Or (Up = 'AND') Or (Up = 'OR') Or (Up = 'XOR') Or
     (Up = 'SHL') Or (Up = 'SHR') Or (Up = 'SAL') Or (Up = 'SAR') Or
     (Up = 'ROL') Or (Up = 'ROR') Or (Up = 'RCL') Or (Up = 'RCR') Or
     (Up = 'LEA') Or (Up = 'XCHG') Or (Up = 'ADC') Or (Up = 'SBB') Or
     (Up = 'BT') Or (Up = 'BTS') Or (Up = 'BTR') Or (Up = 'BTC') Or
     (Up = 'BSF') Or (Up = 'BSR') Or
     (Up = 'MOVZX') Or (Up = 'MOVSX') Or
     (Up = 'SHLD') Or (Up = 'SHRD') Then
  Begin
    If Length(Op2) > 0 Then
      EmitInstr(Up + ' ' + TranslateAsmOperand(PI, Op1) + ',' +
                TranslateAsmOperand(PI, Op2))
    Else
      EmitInstr(Up + ' ' + TranslateAsmOperand(PI, Op1));
    Exit;
  End;

  { Si on arrive ici, emettre tel quel (instruction non reconnue) }
  If Length(Op2) > 0 Then
    EmitInstr(Up + ' ' + TranslateAsmOperand(PI, Op1) + ',' +
              TranslateAsmOperand(PI, Op2))
  Else If Length(Op1) > 0 Then
    EmitInstr(Up + ' ' + TranslateAsmOperand(PI, Op1))
  Else
    EmitInstr(Up);
End;

{ ------------------------------------------------------------ }
{ ParseAsmBlock : parser un bloc ASM...END et traduire chaque   }
{ ligne d assembleur 8086 en assembleur 80386 Win32.            }
{ Syntaxe Turbo Pascal : ASM instruction; instruction; ... END  }
{ Dans le TokenPool, chaque token est un mot ; on reconstruit   }
{ les lignes d assembleur et on les traduit.                    }
{ ------------------------------------------------------------ }

Procedure ParseAsmBlock(PI : Integer);
Var
  AsmLine : TString;
  Up      : TString;
  T       : TString;
Begin
  EmitComment('--- Debut bloc ASM (TODO 17) ---');

  { Consommer le mot-cle ASM }
  If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_KEYWORD) And
     (StrUpperCase(TokenPool[EP].Val) = 'ASM') Then
    Inc(EP);

  { Traiter les tokens jusqu au END correspondant }
  While Not EPAtEnd Do
  Begin
    Up := StrUpperCase(TokenPool[EP].Val);

    { END termine le bloc ASM }
    If (TokenPool[EP].Kind = TK_KEYWORD) And (Up = 'END') Then
    Begin
      Inc(EP);
      { Consommer ; ou . optionnel apres END }
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         ((TokenPool[EP].Val = ';') Or (TokenPool[EP].Val = '.')) Then
        Inc(EP);
      Break;
    End;

    { Point-virgule seul : separateur d instructions, ignorer }
    If (TokenPool[EP].Kind = TK_PUNCT) And (TokenPool[EP].Val = ';') Then
    Begin
      Inc(EP);
      Continue;
    End;

    { Construire une ligne ASM a partir des tokens }
    { Une instruction ASM va jusqu au prochain ; ou END }
    AsmLine := '';
    While Not EPAtEnd Do
    Begin
      { Arreter au ; ou END }
      If (TokenPool[EP].Kind = TK_PUNCT) And (TokenPool[EP].Val = ';') Then
        Break;
      If (TokenPool[EP].Kind = TK_KEYWORD) And
         (StrUpperCase(TokenPool[EP].Val) = 'END') Then
        Break;

      { Verifier si le token suivant est ':' (c est un label ASM) }
      T := TokenPool[EP].Val;
      Inc(EP);

      { Si le prochain token est ':', c est un label }
      If (Not EPAtEnd) And (TokenPool[EP].Kind = TK_PUNCT) And
         (TokenPool[EP].Val = ':') Then
      Begin
        { Emettre le label }
        EmitLabel(T);
        Inc(EP); { consommer ':' }
        Continue;
      End;

      { Ajouter au tampon de la ligne }
      If Length(AsmLine) > 0 Then
        AsmLine := AsmLine + ' ';
      AsmLine := AsmLine + T;
    End;

    { Traduire et emettre la ligne ASM }
    AsmLine := AsmTrimSpaces(AsmLine);
    If Length(AsmLine) > 0 Then
      TranslateAsmLine(PI, AsmLine);
  End;

  EmitComment('--- Fin bloc ASM ---');
End;

{ ------------------------------------------------------------ }
{ EmitMainBlock : emettre le bloc principal du programme        }
{ (le BEGIN..END. final)                                        }
{ ------------------------------------------------------------ }

Procedure EmitMainBlock;
Var
  I    : Integer;
  Up   : TString;
  Depth: Integer;
Begin
  { Chercher le dernier BEGIN au niveau global = bloc principal }
  I := TokenCount - 1;
  While I >= 0 Do
  Begin
    If (TokenPool[I].Kind = TK_KEYWORD) And
       (StrUpperCase(TokenPool[I].Val) = 'END') Then
    Begin
      { Remonter pour trouver le BEGIN correspondant }
      Depth := 1;
      Dec(I);
      While (I >= 0) And (Depth > 0) Do
      Begin
        If TokenPool[I].Kind = TK_KEYWORD Then
        Begin
          Up := StrUpperCase(TokenPool[I].Val);
          If Up = 'END' Then
            Inc(Depth)
          Else If (Up = 'BEGIN') Or (Up = 'CASE') Or (Up = 'RECORD') Or
                  (Up = 'ASM') Then
            Dec(Depth);
        End;
        If Depth > 0 Then Dec(I);
      End;
      If Depth = 0 Then Break;
    End;
    Dec(I);
  End;

  { Si on a trouve le bloc principal, emettre _TPF_Main }
  If (I >= 0) And (TokenPool[I].Kind = TK_KEYWORD) And
     (StrUpperCase(TokenPool[I].Val) = 'BEGIN') Then
  Begin
    HasProgram := True;
    EmitBlankLine;
    EmitComment('--- Programme principal ---');
    EmitLabel(TP_FUNC_PFX + 'Main');
    EmitProlog(0);

    { Initialiser les handles Win32 }
    EmitComment('Obtenir STDOUT');
    EmitInstr('PUSH -11');
    EmitInstr('CALL GetStdHandle');
    EmitInstr('MOV [HSTDOUT],EAX');
    EmitComment('Obtenir STDIN');
    EmitInstr('PUSH -10');
    EmitInstr('CALL GetStdHandle');
    EmitInstr('MOV [HSTDIN],EAX');
    EmitComment('Obtenir le tas du processus');
    EmitInstr('CALL GetProcessHeap');
    EmitInstr('MOV [HHEAP],EAX');

    { Parser et emettre le corps du programme }
    RetLbl := LabelGen;
    EP := I;      { I pointe sur le BEGIN }
    EPEnd := TokenCount;
    CurProcIdx := -1;
    ParseBody(-1);
    EmitLabel(RetLbl);

    { Sortie propre }
    EmitInstr('PUSH 0');
    EmitInstr('CALL ExitProcess');

    EmitEpilog;
  End;
End;

{ ------------------------------------------------------------ }
{ EmitRuntime : emettre les routines runtime internes du        }
{ compilateur dans le segment .CODE.                           }
{ _TPRT_PRINTSTR : afficher chaine ASCIIZ (ESI = pointeur)    }
{ _TPRT_NUMTOSTR : convertir EAX en chaine NUMBUF             }
{ _TPRT_STRTONUM : convertir chaine ASCIIZ (ESI) en EAX       }
{ _TPRT_READLN   : lire une ligne de STDIN dans INBUF         }
{ _TPRT_STRCPY   : copier chaine (ESI -> EDI)                 }
{ _TPRT_STRLEN   : longueur ASCIIZ (ESI) -> EAX  (TODO 16)   }
{ _TPRT_CONCAT   : concatener EDI apres ESI      (TODO 16)   }
{ _TPRT_STRCMP    : comparer ESI et EDI -> EAX    (TODO 16)   }
{ _TPRT_COPY     : sous-chaine -> STRBUF1        (TODO 16)   }
{ _TPRT_POS      : position sous-chaine -> EAX   (TODO 16)   }
{ _TPRT_DELETE    : supprimer in-place            (TODO 16)   }
{ _TPRT_INSERT    : inserer via STRBUF2           (TODO 16)   }
{ ------------------------------------------------------------ }

Procedure EmitRuntime;
Begin
  EmitBlankLine;
  EmitComment('=== Routines runtime TPCW32 ===');

  { ------ _TPRT_PRINTSTR : afficher chaine ASCIIZ ---------- }
  { Entree : ESI = pointeur vers chaine ASCIIZ                }
  { Utilise : WriteFile(HSTDOUT, ESI, len, &BYTESWR, 0)       }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'PRINTSTR');
  EmitInstr('PUSHAD');
  { Calculer la longueur de la chaine }
  EmitInstr('XOR ECX,ECX');
  EmitLabel(TP_RT_PFX + 'PSTR_L');
  EmitInstr('CMP BYTE PTR [ESI+ECX],0');
  EmitInstr('JE ' + TP_RT_PFX + 'PSTR_G');
  EmitInstr('INC ECX');
  EmitInstr('JMP ' + TP_RT_PFX + 'PSTR_L');
  EmitLabel(TP_RT_PFX + 'PSTR_G');
  { ECX = longueur, ESI = debut de la chaine }
  EmitInstr('TEST ECX,ECX');
  EmitInstr('JZ ' + TP_RT_PFX + 'PSTR_D');
  { Appeler WriteFile(HSTDOUT, ESI, ECX, &BYTESWR, 0) }
  EmitInstr('PUSH 0');                     { lpOverlapped         }
  EmitInstr('PUSH OFFSET BYTESWR');        { lpNumberOfBytesWritten }
  EmitInstr('PUSH ECX');                   { nNumberOfBytesToWrite }
  EmitInstr('PUSH ESI');                   { lpBuffer             }
  EmitInstr('PUSH DWORD PTR [HSTDOUT]');   { hFile                }
  EmitInstr('CALL WriteFile');
  EmitLabel(TP_RT_PFX + 'PSTR_D');
  EmitInstr('POPAD');
  EmitInstr('RET');

  { ------ _TPRT_NUMTOSTR : EAX -> NUMBUF (ASCIIZ) ---------- }
  { Entree : EAX = entier signe 32 bits                       }
  { Sortie : NUMBUF contient la representation decimale        }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'NUMTOSTR');
  EmitInstr('PUSHAD');
  EmitInstr('LEA EDI,[NUMBUF]');
  EmitInstr('XOR ECX,ECX');        { compteur de chiffres }
  EmitInstr('TEST EAX,EAX');
  EmitInstr('JGE ' + TP_RT_PFX + 'NTS_POS');
  { Nombre negatif : stocker '-' et inverser }
  EmitInstr('MOV BYTE PTR [EDI],45'); { '-' }
  EmitInstr('INC EDI');
  EmitInstr('NEG EAX');
  EmitLabel(TP_RT_PFX + 'NTS_POS');
  EmitInstr('MOV EBX,10');
  EmitLabel(TP_RT_PFX + 'NTS_DIV');
  EmitInstr('XOR EDX,EDX');
  EmitInstr('DIV EBX');            { EAX=quotient, EDX=reste }
  EmitInstr('ADD DL,48');          { '0' }
  EmitInstr('PUSH EDX');
  EmitInstr('INC ECX');
  EmitInstr('TEST EAX,EAX');
  EmitInstr('JNZ ' + TP_RT_PFX + 'NTS_DIV');
  EmitLabel(TP_RT_PFX + 'NTS_POP');
  EmitInstr('POP EAX');
  EmitInstr('MOV [EDI],AL');
  EmitInstr('INC EDI');
  EmitInstr('DEC ECX');
  EmitInstr('JNZ ' + TP_RT_PFX + 'NTS_POP');
  EmitInstr('MOV BYTE PTR [EDI],0'); { terminateur NUL }
  EmitInstr('POPAD');
  EmitInstr('RET');

  { ------ _TPRT_STRTONUM : ESI -> EAX (entier) ------------- }
  { Entree : ESI = pointeur vers chaine ASCIIZ decimale        }
  { Sortie : EAX = valeur entiere                              }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'STRTONUM');
  EmitInstr('PUSH EBX');
  EmitInstr('PUSH ECX');
  EmitInstr('PUSH EDX');
  EmitInstr('XOR EAX,EAX');
  EmitInstr('XOR ECX,ECX');        { flag signe }
  EmitInstr('CMP BYTE PTR [ESI],45'); { '-' }
  EmitInstr('JNE ' + TP_RT_PFX + 'STN_LP');
  EmitInstr('INC ESI');
  EmitInstr('INC ECX');
  EmitLabel(TP_RT_PFX + 'STN_LP');
  EmitInstr('MOVZX EDX,BYTE PTR [ESI]');
  EmitInstr('TEST DL,DL');
  EmitInstr('JZ ' + TP_RT_PFX + 'STN_DN');
  EmitInstr('CMP DL,48'); { '0' }
  EmitInstr('JB ' + TP_RT_PFX + 'STN_DN');
  EmitInstr('CMP DL,57'); { '9' }
  EmitInstr('JA ' + TP_RT_PFX + 'STN_DN');
  EmitInstr('SUB DL,48');
  EmitInstr('IMUL EAX,EAX,10');
  EmitInstr('ADD EAX,EDX');
  EmitInstr('INC ESI');
  EmitInstr('JMP ' + TP_RT_PFX + 'STN_LP');
  EmitLabel(TP_RT_PFX + 'STN_DN');
  EmitInstr('TEST ECX,ECX');
  EmitInstr('JZ ' + TP_RT_PFX + 'STN_RT');
  EmitInstr('NEG EAX');
  EmitLabel(TP_RT_PFX + 'STN_RT');
  EmitInstr('POP EDX');
  EmitInstr('POP ECX');
  EmitInstr('POP EBX');
  EmitInstr('RET');

  { ------ _TPRT_READLN : lire une ligne de STDIN ----------- }
  { Sortie : INBUF contient la ligne lue, terminee par NUL    }
  { BYTESRD = nombre d octets lus                              }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'READLN');
  EmitInstr('PUSHAD');
  { ReadFile(HSTDIN, INBUF, 255, &BYTESRD, 0) }
  EmitInstr('PUSH 0');                     { lpOverlapped         }
  EmitInstr('PUSH OFFSET BYTESRD');        { lpNumberOfBytesRead  }
  EmitInstr('PUSH 255');                   { nNumberOfBytesToRead  }
  EmitInstr('PUSH OFFSET INBUF');          { lpBuffer             }
  EmitInstr('PUSH DWORD PTR [HSTDIN]');    { hFile                }
  EmitInstr('CALL ReadFile');
  { Retirer CR/LF de fin et terminer par NUL }
  EmitInstr('MOV ECX,DWORD PTR [BYTESRD]');
  EmitLabel(TP_RT_PFX + 'RL_TR');
  EmitInstr('TEST ECX,ECX');
  EmitInstr('JZ ' + TP_RT_PFX + 'RL_DN');
  EmitInstr('DEC ECX');
  EmitInstr('CMP BYTE PTR [INBUF+ECX],13');
  EmitInstr('JE ' + TP_RT_PFX + 'RL_TR');
  EmitInstr('CMP BYTE PTR [INBUF+ECX],10');
  EmitInstr('JE ' + TP_RT_PFX + 'RL_TR');
  EmitInstr('INC ECX');
  EmitLabel(TP_RT_PFX + 'RL_DN');
  EmitInstr('MOV BYTE PTR [INBUF+ECX],0');
  EmitInstr('POPAD');
  EmitInstr('RET');

  { ------ _TPRT_STRCPY : copier chaine ASCIIZ --------------- }
  { Entree : ESI = source, EDI = destination                   }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'STRCPY');
  EmitInstr('PUSH ESI');
  EmitInstr('PUSH EDI');
  EmitLabel(TP_RT_PFX + 'SCPY_L');
  EmitInstr('LODSB');
  EmitInstr('STOSB');
  EmitInstr('TEST AL,AL');
  EmitInstr('JNZ ' + TP_RT_PFX + 'SCPY_L');
  EmitInstr('POP EDI');
  EmitInstr('POP ESI');
  EmitInstr('RET');

  { ============================================================ }
  { TODO 16 - ROUTINES RUNTIME CHAINES           [IMPLEMENTE]    }
  { ============================================================ }

  { ------ _TPRT_STRLEN : longueur ASCIIZ -------------------- }
  { Entree : ESI = pointeur vers chaine ASCIIZ                 }
  { Sortie : EAX = longueur (nombre de caracteres avant NUL)   }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'STRLEN');
  EmitInstr('PUSH ESI');
  EmitInstr('XOR EAX,EAX');
  EmitLabel(TP_RT_PFX + 'SLN_L');
  EmitInstr('CMP BYTE PTR [ESI],0');
  EmitInstr('JE ' + TP_RT_PFX + 'SLN_D');
  EmitInstr('INC EAX');
  EmitInstr('INC ESI');
  EmitInstr('JMP ' + TP_RT_PFX + 'SLN_L');
  EmitLabel(TP_RT_PFX + 'SLN_D');
  EmitInstr('POP ESI');
  EmitInstr('RET');

  { ------ _TPRT_CONCAT : concatener ESI + EDI -> ESI -------- }
  { Entree : ESI = destination (ASCIIZ, deja remplie)           }
  {          EDI = source a ajouter (ASCIIZ)                    }
  { Resultat : ESI est etendu avec EDI a la fin                }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'CONCAT');
  EmitInstr('PUSHAD');
  { Trouver la fin de ESI }
  EmitLabel(TP_RT_PFX + 'CAT_F');
  EmitInstr('CMP BYTE PTR [ESI],0');
  EmitInstr('JE ' + TP_RT_PFX + 'CAT_C');
  EmitInstr('INC ESI');
  EmitInstr('JMP ' + TP_RT_PFX + 'CAT_F');
  EmitLabel(TP_RT_PFX + 'CAT_C');
  { Copier EDI a la fin }
  EmitLabel(TP_RT_PFX + 'CAT_L');
  EmitInstr('MOV AL,BYTE PTR [EDI]');
  EmitInstr('MOV BYTE PTR [ESI],AL');
  EmitInstr('TEST AL,AL');
  EmitInstr('JZ ' + TP_RT_PFX + 'CAT_D');
  EmitInstr('INC ESI');
  EmitInstr('INC EDI');
  EmitInstr('JMP ' + TP_RT_PFX + 'CAT_L');
  EmitLabel(TP_RT_PFX + 'CAT_D');
  EmitInstr('POPAD');
  EmitInstr('RET');

  { ------ _TPRT_STRCMP : comparer ESI et EDI ----------------- }
  { Entree : ESI = chaine 1, EDI = chaine 2 (ASCIIZ)          }
  { Sortie : EAX = <0 si s1<s2, 0 si s1=s2, >0 si s1>s2      }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'STRCMP');
  EmitInstr('PUSH ESI');
  EmitInstr('PUSH EDI');
  EmitLabel(TP_RT_PFX + 'CMP_L');
  EmitInstr('MOVZX EAX,BYTE PTR [ESI]');
  EmitInstr('MOVZX ECX,BYTE PTR [EDI]');
  EmitInstr('SUB EAX,ECX');
  EmitInstr('JNZ ' + TP_RT_PFX + 'CMP_D');
  EmitInstr('TEST ECX,ECX');
  EmitInstr('JZ ' + TP_RT_PFX + 'CMP_D');
  EmitInstr('INC ESI');
  EmitInstr('INC EDI');
  EmitInstr('JMP ' + TP_RT_PFX + 'CMP_L');
  EmitLabel(TP_RT_PFX + 'CMP_D');
  EmitInstr('POP EDI');
  EmitInstr('POP ESI');
  EmitInstr('RET');

  { ------ _TPRT_COPY : Copy(S, Pos, Len) -------------------- }
  { Entree : ESI = source ASCIIZ, EBX = position (1-based),    }
  {          ECX = longueur a copier                            }
  { Sortie : EAX = pointeur vers STRBUF1 (resultat ASCIIZ)    }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'COPY');
  EmitInstr('PUSHAD');
  EmitInstr('LEA EDI,[STRBUF1]');
  { Avancer ESI de (Pos-1) caracteres }
  EmitInstr('DEC EBX');
  EmitInstr('TEST EBX,EBX');
  EmitInstr('JLE ' + TP_RT_PFX + 'CPY_C');
  EmitLabel(TP_RT_PFX + 'CPY_S');
  EmitInstr('CMP BYTE PTR [ESI],0');
  EmitInstr('JE ' + TP_RT_PFX + 'CPY_E');
  EmitInstr('INC ESI');
  EmitInstr('DEC EBX');
  EmitInstr('JNZ ' + TP_RT_PFX + 'CPY_S');
  EmitLabel(TP_RT_PFX + 'CPY_C');
  { Copier ECX caracteres }
  EmitInstr('TEST ECX,ECX');
  EmitInstr('JLE ' + TP_RT_PFX + 'CPY_E');
  EmitLabel(TP_RT_PFX + 'CPY_L');
  EmitInstr('CMP BYTE PTR [ESI],0');
  EmitInstr('JE ' + TP_RT_PFX + 'CPY_E');
  EmitInstr('MOVSB');
  EmitInstr('DEC ECX');
  EmitInstr('JNZ ' + TP_RT_PFX + 'CPY_L');
  EmitLabel(TP_RT_PFX + 'CPY_E');
  EmitInstr('MOV BYTE PTR [EDI],0');
  EmitInstr('POPAD');
  EmitInstr('LEA EAX,[STRBUF1]');
  EmitInstr('RET');

  { ------ _TPRT_POS : Pos(SubStr, S) -> EAX ----------------- }
  { Entree : EDI = sous-chaine, ESI = chaine (ASCIIZ)          }
  { Sortie : EAX = position 1-based, ou 0 si non trouve        }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'POS');
  EmitInstr('PUSH EBX');
  EmitInstr('PUSH ECX');
  EmitInstr('PUSH EDX');
  EmitInstr('PUSH ESI');
  EmitInstr('PUSH EDI');
  EmitInstr('XOR EAX,EAX');
  EmitInstr('XOR EBX,EBX');        { index courant (0-based) }
  EmitLabel(TP_RT_PFX + 'POS_O');
  EmitInstr('CMP BYTE PTR [ESI+EBX],0');
  EmitInstr('JE ' + TP_RT_PFX + 'POS_N');
  { Comparer EDI avec ESI+EBX }
  EmitInstr('XOR ECX,ECX');
  EmitLabel(TP_RT_PFX + 'POS_M');
  EmitInstr('MOVZX EDX,BYTE PTR [EDI+ECX]');
  EmitInstr('TEST DL,DL');
  EmitInstr('JZ ' + TP_RT_PFX + 'POS_F'); { fin du pattern = trouve }
  EmitInstr('CMP DL,BYTE PTR [ESI+EBX+ECX]');
  EmitInstr('JNE ' + TP_RT_PFX + 'POS_X');
  EmitInstr('INC ECX');
  EmitInstr('JMP ' + TP_RT_PFX + 'POS_M');
  EmitLabel(TP_RT_PFX + 'POS_F');
  { Trouve a la position EBX+1 }
  EmitInstr('LEA EAX,[EBX+1]');
  EmitInstr('JMP ' + TP_RT_PFX + 'POS_D');
  EmitLabel(TP_RT_PFX + 'POS_X');
  EmitInstr('INC EBX');
  EmitInstr('JMP ' + TP_RT_PFX + 'POS_O');
  EmitLabel(TP_RT_PFX + 'POS_N');
  EmitInstr('XOR EAX,EAX');        { pas trouve }
  EmitLabel(TP_RT_PFX + 'POS_D');
  EmitInstr('POP EDI');
  EmitInstr('POP ESI');
  EmitInstr('POP EDX');
  EmitInstr('POP ECX');
  EmitInstr('POP EBX');
  EmitInstr('RET');

  { ------ _TPRT_DELETE : Delete(S, Pos, Len) in-place -------- }
  { Entree : ESI = pointeur buffer ASCIIZ                       }
  {          EBX = position (1-based), ECX = nombre a supprimer }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'DELETE');
  EmitInstr('PUSHAD');
  EmitInstr('DEC EBX');
  { EDI = debut zone a supprimer, ESI = debut zone apres }
  EmitInstr('MOV EDI,ESI');
  EmitInstr('ADD EDI,EBX');
  EmitInstr('ADD ESI,EBX');
  EmitInstr('ADD ESI,ECX');
  EmitLabel(TP_RT_PFX + 'DEL_L');
  EmitInstr('LODSB');
  EmitInstr('STOSB');
  EmitInstr('TEST AL,AL');
  EmitInstr('JNZ ' + TP_RT_PFX + 'DEL_L');
  EmitInstr('POPAD');
  EmitInstr('RET');

  { ------ _TPRT_INSERT : Insert(Src, Dst, Pos) -------------- }
  { Entree : ESI = source ASCIIZ a inserer                     }
  {          EDI = destination buffer ASCIIZ                     }
  {          EBX = position d insertion (1-based)               }
  { Utilise STRBUF2 comme buffer temporaire                     }
  EmitBlankLine;
  EmitLabel(TP_RT_PFX + 'INSERT');
  EmitInstr('PUSHAD');
  EmitInstr('DEC EBX');
  { Copier destination dans STRBUF2 }
  EmitInstr('PUSH ESI');
  EmitInstr('PUSH EDI');
  EmitInstr('MOV ESI,EDI');
  EmitInstr('LEA EDI,[STRBUF2]');
  EmitInstr('CALL ' + TP_RT_PFX + 'STRCPY');
  EmitInstr('POP EDI');
  EmitInstr('POP ESI');
  { EDI = debut du buffer destination }
  { Copier les EBX premiers caracteres de STRBUF2 dans EDI }
  EmitInstr('PUSH ESI');
  EmitInstr('PUSH EBX');
  EmitInstr('LEA ESI,[STRBUF2]');
  EmitInstr('MOV ECX,EBX');
  EmitInstr('TEST ECX,ECX');
  EmitInstr('JZ ' + TP_RT_PFX + 'INS_P2');
  EmitLabel(TP_RT_PFX + 'INS_P1');
  EmitInstr('MOVSB');
  EmitInstr('DEC ECX');
  EmitInstr('JNZ ' + TP_RT_PFX + 'INS_P1');
  EmitLabel(TP_RT_PFX + 'INS_P2');
  { Copier la source (ESI original) dans EDI }
  EmitInstr('POP EBX');
  EmitInstr('POP ESI');
  EmitLabel(TP_RT_PFX + 'INS_S1');
  EmitInstr('CMP BYTE PTR [ESI],0');
  EmitInstr('JE ' + TP_RT_PFX + 'INS_S2');
  EmitInstr('MOVSB');
  EmitInstr('JMP ' + TP_RT_PFX + 'INS_S1');
  EmitLabel(TP_RT_PFX + 'INS_S2');
  { Copier le reste de STRBUF2 a partir de la position EBX }
  EmitInstr('LEA ESI,[STRBUF2]');
  EmitInstr('ADD ESI,EBX');
  EmitLabel(TP_RT_PFX + 'INS_R1');
  EmitInstr('LODSB');
  EmitInstr('STOSB');
  EmitInstr('TEST AL,AL');
  EmitInstr('JNZ ' + TP_RT_PFX + 'INS_R1');
  EmitInstr('POPAD');
  EmitInstr('RET');
End;

{ ------------------------------------------------------------ }
{ Run                                                          }
{ ------------------------------------------------------------ }

Procedure Run;
Begin
  ShowBanner;

  { Ouvrir le fichier source }
  Assign(LexSrcF, Opts.SrcFile);
  {$I-}
  Reset(LexSrcF);
  {$I+}
  If IOResult <> 0 Then
    FatalError('impossible d''ouvrir le fichier source: ' + Opts.SrcFile);
  LexOpened := True;
  LexSrcFName := Opts.SrcFile;

  { Initialiser le pool de donnees et le pool de tokens (TODO 04) }
  DataInit;
  TokenPoolInit;

  { Initialiser la table des symboles (TODO 05) }
  SymInit;

  { Initialiser le systeme de types (TODO 06) }
  TypeInit;

  { Initialiser le preprocesseur }
  PPInitDefines;

  { Initialiser le lexeur et scanner les tokens dans le pool }
  LexInit;
  Repeat
    LexNextToken;
    If CurToken.Kind <> TK_EOF Then
      TokenPoolAdd(CurToken);
  Until CurToken.Kind = TK_EOF;

  { Enregistrer toutes les chaines dans le pool de donnees }
  TokenPoolRegisterStrings;

  If Opts.Verbose Then
    WriteLn('  Tokens: ', TokenCount, '  Donnees: ', DataCount,
            '  Symboles: ', SymCount, '  Types: ', TypeCount);

  { Initialiser les variables de l emetteur (TODO 07) }
  HasProgram := False;
  DataEmittedCount := 0;
  EmitLabelSeq := 0;
  StaticVarSeq := 0;

  { Analyser les declarations TYPE (TODO 15) }
  ParseTypeDecls;

  { Analyser les declarations globales VAR et CONST (TODO 08) }
  ParseDataDecls;

  If Opts.Verbose Then
    WriteLn('  Apres ParseDataDecls: Donnees=', DataCount,
            '  Symboles=', SymCount);

  { Analyser les declarations PROCEDURE et FUNCTION (TODO 09) }
  ParseProcDecls;

  If Opts.Verbose Then
    WriteLn('  Apres ParseProcDecls: Procedures=', ProcCount,
            '  Symboles=', SymCount);

  { Generation du fichier .ASM si demande (TODO 07) }
  If Opts.AsmOutput Then
  Begin
    EmitOpen(ReplaceExt(Opts.OutFile, '.asm'));
    EmitHeader;
    EmitDataSeg;
    EmitCodeSeg;

    { Emettre les procedures et fonctions (TODO 09) }
    EmitProcedures;

    { Emettre le bloc principal (TODO 09) }
    EmitMainBlock;

    { Emettre les routines runtime (TODO 12) }
    EmitRuntime;

    { TODO 13..25 : compilation complete }

    EmitClose;
    If Opts.Verbose Then
      WriteLn('  ASM genere : ', ReplaceExt(Opts.OutFile, '.asm'));
  End;

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

  ParseArgs;
  Run;
  Cleanup;
  Halt(EXIT_OK);
END.
