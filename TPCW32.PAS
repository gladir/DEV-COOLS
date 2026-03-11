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

  TODO 02 - LEXEUR (TOKENS TURBO PASCAL)
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

  TODO 03 - PREPROCESSEUR ET DIRECTIVES DE COMPILATION
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

  TODO 04 - LITTERAUX ET CONSTANTES
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

  TODO 05 - TABLE DES SYMBOLES
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

  TODO 06 - SYSTEME DE TYPES
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

  TODO 07 - EMETTEUR DE CODE ASM 80386
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

  TODO 08 - SEGMENT DE DONNEES ET STATIQUES
            TDataRec : LblName, Kind (DK_DWORD/DK_BYTE/DK_STR/
              DK_ARRAY/DK_RECORD/DK_ZERO), IntVal, StrVal,
              ElemCount
            DataTab[0..MAX_DATA-1], DataCount
            DataAdd, DataAddStr, DataAddRecord
            Variables globales : entrees DD/DB dans .DATA
            Constantes typees : CONST x: Integer = 42 -> DD 42
            Chaines litterales : DB 'Hello',0 avec label _TPK_N
            Tables de methodes virtuelles (VMT) pour objets
            Variables de runtime :
              HSTDOUT DD 0, HSTDIN DD 0, HHEAP DD 0
              NUMBUF, INBUF, BYTESWR, BYTESRD, CRLF

  TODO 09 - VARIABLES ET AFFECTATIONS
            Variables globales : segment .DATA, acces par label _TPV_nom
            Variables locales : pile EBP, acces [EBP-offset]
            Parametres par valeur : copie sur pile
            Parametres par reference (VAR) : adresse sur pile
            Parametres constantes (CONST) : par reference, lecture seule
            Affectation := : ParseExpr + MOV destination, EAX
            Affectation de record : copie champ par champ ou REP MOVSD
            Affectation de string : copie avec longueur
            Variables non typees (Var F: File) : handle fichier

  TODO 10 - EXPRESSIONS PRIMAIRES
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

  TODO 11 - EXPRESSIONS BINAIRES ET PRECEDENCE
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

  TODO 12 - ENTREES/SORTIES (Write / WriteLn / Read / ReadLn)
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

  TODO 13 - STRUCTURES DE CONTROLE
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

  TODO 14 - PROCEDURES ET FONCTIONS
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

  TODO 15 - TABLEAUX, RECORDS, ENSEMBLES ET OBJETS
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

  TODO 16 - CHAINES DE CARACTERES
            ShortString : String[n] (longueur max 255)
              Octet 0 = longueur, octets 1..n = caracteres
            PChar : pointeur vers chaine terminee par #0
            Concatenation + : CALL _TPRT_CONCAT
            Comparaison : CALL _TPRT_STRCMP -> drapeaux
            Copy(S, Pos, Len) : sous-chaine -> _TPRT_COPY
            Delete(S, Pos, Len) : suppression -> _TPRT_DELETE
            Insert(Src, Dst, Pos) : insertion -> _TPRT_INSERT
            Pos(SubStr, S) : recherche -> _TPRT_POS
            Length(S) : longueur -> MOVZX EAX, BYTE PTR [S]
            Concat(S1, S2, ...) : concatenation multiple
            Str(N, S) / Val(S, N, Code) : conversions
            Upcase(Ch) : majuscule d un caractere
            Chr(N) / Ord(Ch) : conversions char <-> entier
            S[i] : acces direct au ieme caractere

  TODO 17 - INSTRUCTION ASM ET TRADUCTION 8086 -> 80386
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

{ ------------------------------------------------------------ }
{ Run (stub - sera complete par les TODOs suivants)            }
{ ------------------------------------------------------------ }

Procedure Run;
Begin
  ShowBanner;
  { TODO 02..25 : compilation complete }
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
