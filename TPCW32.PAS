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

{ Sauter commentaire accolade }
Procedure LexSkipBraceComment;
Begin
  { Directive dollar ignoree pour TODO 03 }
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
    Else If FltVal < -2147483648.0 Then N := -2147483647
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

  { Initialiser le lexeur et scanner les tokens }
  LexInit;
  LexNextToken;
  While CurToken.Kind <> TK_EOF Do
    LexNextToken;

  { TODO 03..25 : compilation complete }

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
