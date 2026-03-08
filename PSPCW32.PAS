{ @author: Sylvain Maltais
  @created: 2026
  @version: 1.0
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
  @description: Compilateur PSP (Pascal Server Pages) vers assembleur 80386 pour Windows 32 bits
  @license: MIT
}

(* ============================================================
  PSPCW32.PAS - Compilateur Pascal Server Pages vers assembleur
  80386 pour Windows 32 bits
  Turbo Pascal / Free Pascal (-Mtp)
  Cible : MASM .386 / .MODEL FLAT, PE Win32

  Par defaut produit un fichier .EXE (PE Windows 32 bits).
  Avec le parametre -obj, produit uniquement un fichier .OBJ (COFF).
  Avec le parametre -asm, produit egalement un fichier .ASM lisible.
  Supporte toutes les instructions de PSP86.PAS et les exemples
  SAMPLES\PSP\*

  FEUILLE DE ROUTE - 25 TODOS
  ============================================================

  TODO 01 - INFRASTRUCTURE ET OPTIONS [IMPLEMENTE]
            TOptions (SrcFile, OutFile, Verbose, DebugMode, Warnings,
              EmitExe, EmitObj, EmitAsm)
            ParseArgs : analyser argv (source.psp [-o sortie] [-v] [-d]
              [-w] [-obj] [-asm] [-h])
            Par defaut : produire un .EXE Windows 32 bits (PE)
            -obj : produire uniquement un .OBJ (format COFF 32 bits)
            -asm : produire egalement un listing assembleur .ASM lisible
            -o nom : specifier le nom du fichier de sortie
            FatalError, WarnMsg, EXIT_OK / EXIT_ERROR / EXIT_USAGE
            Detecter l extension .psp du fichier source
            Programme principal : validation des arguments et appel Run
            Version, Date, aide en ligne (option -h)

  TODO 02 - LEXEUR PSP (TOKENS PASCAL ET BALISES HTML) [IMPLEMENTE]
            TTokenKind : TK_EOF, TK_INTEGER, TK_REAL, TK_CHAR,
              TK_STRING, TK_IDENT, TK_KEYWORD, TK_OP, TK_PUNCT,
              TK_HTML, TK_PSP_OPEN, TK_PSP_CLOSE, TK_PSP_EXPR_OPEN,
              TK_PSP_DIRECTIVE
            TPSPMode : TPL_HTML (texte HTML), TPL_CODE (code Pascal)
            LexInit, LexClose, LexNextToken, LexScanIdent, LexScanNumber
            TplNextToken : aiguillage HTML / code selon TPSPMode
              En mode TPL_HTML : accumuler le texte HTML jusqu a <% ou EOF
              Detecter <% (code), <%= (expression inline), <%@ (directive)
              En mode TPL_CODE : lexer les tokens Pascal jusqu a %>
            LexScanString : chaine entre apostrophes 'abc' avec '' echappement
            LexScanChar : notation #65 ou #$41 (caractere ASCII)
            Commentaires : accolades, parenthese-etoile, double-slash //
            Mots-cles Pascal : AND ARRAY BEGIN BREAK CASE CONST CONTINUE
              DIV DO DOWNTO ELSE END EXCEPT EXIT FINALLY FOR FORWARD
              FUNCTION IF MOD NOT OF OR PROCEDURE PROGRAM RAISE
              RECORD REPEAT RESULT SHL SHR THEN TO TRY TYPE UNTIL
              VAR WHILE WITH XOR
            Mode debug -d : affichage de chaque token avec PrintToken

  TODO 03 - LITTERAUX ET CONSTANTES [IMPLEMENTE]
            Entiers decimaux : 0..2147483647 (32 bits signe)
            Entiers hexadecimaux : $FF, $DEADBEEF (prefixe $)
            Reels : reconnus par le lexeur, tronques en entiers (avertissement)
            Caracteres : #65 ou #$41 -> valeur ordinale dans EAX
            Chaines : 'abc' -> pointeur vers donnees .DATA (ASCIIZ)
              Apostrophe echappee : '' -> un seul caractere '
            Constantes nommees : CONST name = expr;
            Constantes typees : CONST name: Type = expr; (en .DATA)
            NIL : pointeur nul -> EAX=0
            TRUE : booleen -> EAX=1
            FALSE : booleen -> EAX=0

  TODO 04 - OPERATEURS ET PRECEDENCE [IMPLEMENTE]
            Arithmetiques  : + - * / DIV MOD (entiers 32 bits)
            Comparaison    : = <> < > <= >=
            Logiques       : AND OR NOT (court-circuit)
            Bits           : AND OR XOR NOT SHL SHR (selon contexte)
            Concatenation  : + (si un operande est String -> _PSPRT_CONCAT)
            Unaire         : + - (signe) NOT (negation logique/bits)
              @ (adresse-de -> LEA EAX,[var])
            Affectation    : := (assignation)
            Precedence (du plus fort au plus faible) :
              1. NOT, unaire +/-, @
              2. * / DIV MOD AND SHL SHR
              3. + - OR XOR
              4. = <> < > <= >= IN

  TODO 05 - TABLE DES SYMBOLES [IMPLEMENTE]
            TSymCat : SC_VAR, SC_CONST, SC_TYPED_CONST, SC_PARAM,
              SC_VARPARAM, SC_FUNC, SC_PROC, SC_TYPE, SC_FIELD,
              SC_ENUM_VAL, SC_LABEL
            TSymRec : Name, MangledName, Cat, TypeIdx, Offset,
              ScopeLevel, ScopeId, IsForward, IsLocal, ImmVal, DataIdx,
              ParamCnt, VarParamMask
            SymAdd, SymFind, SymFindInScope, SymMangle
            CurScope : compteur de portee imbriquee (max MAX_SCOPE)
            SymEnterScope / SymLeaveScope : gestion des portees
            Prefixes de nommage ASM 32 bits :
              _PSP_ (variable), _PSPF_ (fonction), _PSPK_ (chaine),
              _PSPRT_ (runtime), _PSPL_ (label), _PSPA_ (tableau),
              _PSPR_ (record), _PSPE_ (enum), _PSPX_ (exception)
            Predeclarations des procedures et fonctions standards

  TODO 06 - SYSTEME DE TYPES (32 BITS) [IMPLEMENTE]
            TTypeKind : TKP_INTEGER (32 bits signe), TKP_WORD (32 bits
              non signe), TKP_BYTE (8 bits), TKP_CHAR (8 bits),
              TKP_BOOLEAN (8 bits etendu 32), TKP_STRING (ptr ASCIIZ 32),
              TKP_REAL (tronque en entier 32 bits), TKP_ARRAY,
              TKP_RECORD, TKP_ENUM, TKP_SUBRANGE, TKP_POINTER (32 bits),
              TKP_NIL, TKP_TEXT (handle fichier 32 bits), TKP_VOID
            TypeTab, TypeInit : enregistrer les types primitifs et utilisateur
            TypeSizeof : INTEGER=4, WORD=4, BYTE=1, CHAR=1, BOOLEAN=1,
              STRING=4 (ptr), POINTER=4, TEXT=4
            TypeCanCoerce : Byte<->Integer, Char<->Integer, Boolean->Integer,
              nil->tout pointeur/String, Real<->Integer, Enum->Integer
            TypeCoerceResult : promotion vers le type le plus large
            TypeInfer, TypeLookupName (insensible a la casse)

  TODO 07 - EMETTEUR DE CODE ASM 80386 [IMPLEMENTE]
            TEmitter : OutF (Text), OutFOpen, EmitOpen, EmitClose
            EmitRaw, EmitLabel, EmitInstr (formatage 8 espaces)
            EmitComment, EmitBlankLine
            LabelGen global (compteur unique _PSPL_NNNNN)
            EmitHeader : .386 / .MODEL FLAT, STDCALL / OPTION CASEMAP:NONE
              INCLUDE windows.inc (ou declarations EXTRN manuelles)
              .STACK 4096
              Declarations EXTRN pour API Win32 :
                ExitProcess, GetStdHandle, WriteFile, ReadFile,
                GetProcessHeap, HeapAlloc, HeapFree
              _TEXT SEGMENT DWORD PUBLIC 'CODE' / ASSUME CS:_TEXT
              Point d entree _PSPF_main
            EmitProlog / EmitEpilog : PUSH EBP / MOV EBP,ESP / SUB ESP,n
              et MOV ESP,EBP / POP EBP / RET
            EmitDataSeg : .DATA SEGMENT ... avec variables et litteraux
            Mode -asm : ecrire le fichier .ASM lisible avec commentaires

  TODO 08 - SEGMENT DE DONNEES ET STATIQUES [IMPLEMENTE]
            TDataRec : LblName, Kind (DK_DWORD/DK_BYTE/DK_STR/DK_ARRAY/
              DK_REC), IntVal, StrVal, ElemCount, ElemSize, RecSize
            DataTab[0..MAX_DATA-1], DataCount
            DataAdd, DataAddStr, DataAddArray, DataAddRecord
            Variables globales : entrees DK_DWORD (32 bits) dans .DATA
            Constantes typees : entrees DK_DWORD ou DK_STR (immuables)
            Chaines litterales : DB 'abc',0 avec label _PSPK_N
            Fragments HTML : DB '...',0 avec label _PSPK_HTML_N
            Tampons runtime : _PSPRT_STRBUF (512), _PSPRT_NUMBUF (12),
              _PSPRT_CHRBUF (2), _PSPRT_CRLF DB 13,10,0
            Handles stdout : _PSPRT_HSTDOUT DD 0 (initialise au demarrage)

  TODO 09 - VARIABLES ET AFFECTATIONS (32 BITS) [IMPLEMENTE]
            Variables globales : segment .DATA, acces par label _PSP_nom
              MOV EAX,[_PSP_nom] / MOV [_PSP_nom],EAX
            Variables locales : pile EBP, acces [EBP-offset]
              Taille 4 octets par defaut (DWORD), 1 pour Byte/Char/Boolean
            Parametres VALUE : copie sur pile (comme variable locale)
            Parametres VAR : passage par adresse (pointeur 32 bits sur pile)
            Affectation := : ExprFlushToEAX + MOV [destination], EAX
            Adressage 32 bits : [EBP-n] pour locales, [EBP+n] pour params
            ExprAddrOf, ExprStore, ExprLoad, ExprFlushToEAX
            DeclAllocGlobal / DeclAllocLocal

  TODO 10 - EXPRESSIONS PRIMAIRES [IMPLEMENTE]
            ParsePrimary : literal entier, literal chaine, literal char,
              TRUE, FALSE, NIL, identificateur, appel de fonction,
              expression parenthesee (expr)
            Acces variable : SymFind -> ExprLoad (MOV EAX,[addr])
            Acces champ record : expr.champ -> offset dans RECORD
            Acces index tableau : expr[i] -> calcul offset 32 bits
            Appel de fonction : ParseCallArgs (PUSH args) + CALL _PSPF_fn
              Convention STDCALL : arguments droite a gauche, callee cleanup
            Fonctions predefinies en ligne :
              Length, Ord, Chr, Lo, Hi, Swap, SizeOf, Low, High,
              Abs, Sqr, Odd, Succ, Pred, Inc, Dec
            Expression en ligne PSP : <%= expr %> -> evaluer et ecrire

  TODO 11 - EXPRESSIONS BINAIRES [IMPLEMENTE]
            ParseExprPrec(MinPrec) : boucle de precedence (Pratt parser)
            Arithmetique entiere 32 bits : ADD/SUB/IMUL/IDIV pour +,-,*,DIV
            MOD : IDIV -> resultat dans EDX (reste)
            Division / : IDIV avec resultat dans EAX (quotient)
            Comparaison : CMP + Jcc (JE/JNE/JL/JG/JLE/JGE) -> SETcc + MOVZX
            Comparaison chaines : CALL _PSPRT_STRCMP -> CMP EAX,0 + Jcc
            Concatenation chaines : + -> CALL _PSPRT_CONCAT(ESI,EDI) -> EAX
            Logique AND : court-circuit TEST EAX,EAX / JZ vers false
            Logique OR : court-circuit TEST EAX,EAX / JNZ vers true
            Logique NOT : XOR EAX,1 (booleen) ou NOT EAX (bits)
            Bits : AND/OR/XOR EAX,EBX / SHL EAX,CL / SHR EAX,CL
            Repli de constantes (constant folding) pour operandes immediats

  TODO 12 - ENTREES/SORTIES (Write / WriteLn / Read / ReadLn) [IMPLEMENTE]
            Ecriture via API Win32 WriteFile :
              GetStdHandle(STD_OUTPUT_HANDLE) -> _PSPRT_HSTDOUT
              WriteFile(hStdOut, ptr, len, &written, NULL)
            Write(expr1, expr2, ...) : evaluer chaque argument,
              convertir en chaine selon le type :
              Integer -> CALL _PSPRT_NUMTOSTR / String -> directement /
              Char -> CALL _PSPRT_CHR / Boolean -> 'TRUE'|'FALSE'
              Puis CALL _PSPRT_PRINTSTR pour chaque argument
            WriteLn([args]) : comme Write + ecriture CR+LF
            Format :width -> stocke mais ignore (avertissement)
            Read(var) : ReadFile depuis STD_INPUT_HANDLE
              Type Char/String -> lire un caractere -> variable
              Type Integer -> lire chaine + CALL _PSPRT_STRTONUM
            ReadLn(var) : Read + consommer jusqu a CR+LF
            Expression inline <%= expr %> : evaluer, convertir, ecrire

  TODO 13 - IF / CASE / BLOCS BEGIN..END [IMPLEMENTE]
            ParseIfStmt : IF cond THEN stmt [ELSE stmt]
              Emission TEST EAX,EAX / JZ pour condition fausse
              Labels : _PSPL_ELSE_N, _PSPL_ENDIF_N
              Gestion du dangling else (attachement au if le plus proche)
            ParseCaseStmt : CASE expr OF val: stmt; [val: stmt;] [ELSE stmt] END
              Valeurs simples : CMP EAX,val / JE label_branche
              Intervalles : val1..val2 -> CMP EAX,val1 / JL skip /
                CMP EAX,val2 / JG skip -> JMP branche
              Valeurs multiples : val1, val2, val3 : stmt
              Labels : _PSPL_CASE_N, _PSPL_CEND_N
            ParseBlock : BEGIN stmt [; stmt] END

  TODO 14 - BOUCLES : FOR / WHILE / REPEAT / BREAK / CONTINUE [IMPLEMENTE]
            ParseForStmt : FOR id := lo TO|DOWNTO hi DO stmt
              Variable locale ou globale comme compteur
              TO : increment par INC EAX / CMP EAX,hi / JLE boucle
              DOWNTO : decrement par DEC EAX / CMP EAX,lo / JGE boucle
              Labels : _PSPL_FTEST_N, _PSPL_FINCR_N, _PSPL_FEND_N
            ParseWhileStmt : WHILE cond DO stmt
              Labels : _PSPL_WTEST_N, _PSPL_WEND_N
            ParseRepeatStmt : REPEAT stmts UNTIL cond
              Labels : _PSPL_RBEG_N, _PSPL_RTEST_N
            BREAK : JMP vers label de fin de boucle englobante
            CONTINUE : JMP vers label de test/increment de boucle
            LoopPush / LoopPop : pile de labels pour break/continue
              (max MAX_LOOP_NEST niveaux d imbrication)

  TODO 15 - TABLEAUX (ARRAY) [IMPLEMENTE]
            ARRAY [lo..hi] OF T : tableau a bornes fixes
              Taille = (hi - lo + 1) * sizeof(T) en 32 bits
              Acces : MOV EAX,[base + (index - lo) * elemsize]
              Adresse : LEA EAX,[_PSPA_nom + offset]
            Variables tableau globales : bloc dans .DATA (DK_ARRAY)
            Variables tableau locales : reserve sur pile [EBP-offset]
            Lecture element : ParseArrayAccess -> calcul index 32 bits
            Ecriture element : arr[i] := expr -> MOV [addr],EAX
            Length(arr) : constante hi - lo + 1
            Low(arr) : constante lo
            High(arr) : constante hi
            SizeOf(arr) : constante (hi - lo + 1) * sizeof(element)
            Verification de bornes (optionnelle) : CMP + JB/JAE -> erreur

  TODO 16 - ENREGISTREMENTS (RECORD) ET WITH [IMPLEMENTE]
            TYPE TRec = RECORD champ1: T1; champ2: T2; ... END;
              Taille = somme des sizeof(Ti) alignes sur 4 octets
              Acces champ : offset fixe depuis debut du record
              Records globaux : bloc dans .DATA (DK_REC)
              Records locaux : reserve sur pile [EBP-offset]
            Lecture champ : MOV EAX,[base + field_offset]
            Ecriture champ : MOV [base + field_offset],EAX
            Acces imbrique : rec.champ1.champ2 -> offsets cumules
            ParseWithStmt : WITH RecVar DO stmt
              Empiler le record courant sur la pile WITH
              Les champs du record sont accessibles sans prefixe
              Imbrication max : MAX_WITH niveaux
            Passage de records en parametre : par adresse (pointeur)

  TODO 17 - ENUMERATIONS ET SOUS-INTERVALLES [IMPLEMENTE]
            TYPE TEnum = (Val1, Val2, Val3, ...);
              Valeurs ordinales automatiques 0, 1, 2, ...
              Chaque valeur ajoutee a la table des symboles (SC_ENUM_VAL)
              Ord(EnumVal) -> constante immediate
              Utilisable dans CASE OF et comparaisons
            TYPE TSubRange = lo..hi;
              Sous-intervalle d un type ordinal
              Lo et Hi stockes dans TTypeRec
              Verification optionnelle de bornes a l execution
            Low(T) : borne inferieure du type/tableau
            High(T) : borne superieure du type/tableau
            Succ(x) : ADD EAX,1
            Pred(x) : SUB EAX,1

  TODO 18 - PROCEDURES ET FONCTIONS [IMPLEMENTE]
            ParseProcDecl / ParseFuncDecl :
              PROCEDURE nom[(params)]; [declarations] BEGIN stmts END;
              FUNCTION nom[(params)]: Type; [declarations] BEGIN stmts END;
            Parametres par valeur : copie DWORD sur pile
            Parametres VAR : LEA + PUSH adresse (pointeur 32 bits)
            Parametres multiples meme type : a, b, c: Integer
            Convention d appel : STDCALL (callee nettoie la pile)
              Arguments empiles droite a gauche
              Retour dans EAX
            Prologue : PUSH EBP / MOV EBP,ESP / SUB ESP,locals_size
              PUSH ESI / PUSH EDI (sauvegarde registres)
            Epilogue : POP EDI / POP ESI / MOV ESP,EBP / POP EBP / RET n
            FORWARD : declaration anticipee (resolue plus tard)
            EXIT : retour premature -> JMP vers label epilogue
            Retour fonction : Name := expr ou Result := expr -> MOV EAX,val
            Variables locales : VAR dans le bloc de la procedure/fonction
            Constantes locales : CONST dans le bloc
            Procedures/fonctions imbriquees (max NEST_MAX niveaux)
              Acces au cadre englobant via lien statique

  TODO 19 - TEMPLATE PSP (HTML / <%  %> / <%= %> / <%@ %>) [IMPLEMENTE]
            Mode template PSP : alternance HTML / code Pascal
            Texte HTML statique : accumule et emis via _PSPRT_PRINTSTR
              Chaque fragment recoit un label _PSPK_HTML_N dans .DATA
              Emission : PUSH OFFSET _PSPK_HTML_N / CALL _PSPRT_PRINTSTR
            Balise <% ... %> : bloc de code Pascal (instructions)
              Transition TPL_HTML -> TPL_CODE sur <%
              Transition TPL_CODE -> TPL_HTML sur %>
            Balise <%= expr %> : expression inline
              Evaluer l expression, convertir en chaine, ecrire sur stdout
              Types : Integer -> _PSPRT_NUMTOSTR / String -> directement /
                Boolean -> 'TRUE'|'FALSE' / Char -> _PSPRT_CHR
            Balise <%@ attr="val" %> : directive de page
              ContentType="text/html" -> ecrire entete HTTP Content-Type
              Include="file.inc" -> inclure un fichier source
              Language="pascal" -> reconnu et ignore (toujours Pascal)
              CodePage="..." -> reconnu, avertissement (non supporte)
            Gestion du programme principal implicite :
              Si pas de PROGRAM..BEGIN..END, le template est le programme
              Le code entre <% %> forme le corps du programme principal

  TODO 20 - DIRECTIVES DE COMPILATION [IMPLEMENTE]
            [$I fichier] ou [$INCLUDE fichier] : inclusion de fichier
              Profondeur maximale : MAX_INCLUDE niveaux
              Sauvegarde/restauration de l etat du lexeur
            [$DEFINE nom] : definir un symbole de compilation
            [$UNDEF nom] : supprimer un symbole de compilation
            [$IFDEF nom] : compilation conditionnelle (si defini)
            [$IFNDEF nom] : compilation conditionnelle (si non defini)
            [$ELSE] : branche alternative de la condition
            [$ENDIF] : fin du bloc conditionnel
            [$MODE TP|FPC] : mode de compatibilite (reconnu, ignore)
            Table des defines : MAX_DEFINE entrees
            Commentaires avec directives : accolades peuvent contenir $directives
            Imbrication conditionnelle supportee

  TODO 21 - EXCEPTIONS (TRY / EXCEPT / FINALLY / RAISE)
            ParseTryStmt : TRY stmts EXCEPT [handler] [FINALLY stmts] END
              TRY : sauvegarder ancien handler, installer nouveau
                MOV [_PSPX_HANDLER], OFFSET _PSPL_EXCEPT_N
                MOV [_PSPX_SAVEESP], ESP
                MOV [_PSPX_SAVEEBP], EBP
              EXCEPT : label _PSPL_EXCEPT_N
                Restaurer ESP et EBP depuis sauvegardes
                Restaurer ancien handler
                ON E: ExceptionType DO stmt (optionnel, pattern matching)
              FINALLY : label _PSPL_FINALLY_N
                Execute dans tous les cas (succes ou exception)
                Restaurer ancien handler
            RAISE [expr] : lever une exception
              MOV EAX, code_exception
              JMP [_PSPX_HANDLER] (saut vers handler actif)
              Si pas de handler : CALL _PSPRT_PANIC
            Donnees exception dans .DATA :
              _PSPX_HANDLER DD 0 (adresse handler courant)
              _PSPX_SAVEESP DD 0 (ESP sauvegarde)
              _PSPX_SAVEEBP DD 0 (EBP sauvegarde)
            _PSPRT_PANIC : affiche message d erreur + ExitProcess(1)

  TODO 22 - FONCTIONS DE CHAINES ET RUNTIME STRING
            Fonctions de chaines (appels runtime 32 bits) :
              Length(s)         -> CALL _PSPRT_STRLEN(ESI=s) -> EAX
              Copy(s, pos, len) -> CALL _PSPRT_COPY(ESI,EBX,ECX) -> EAX
              Pos(sub, s)       -> CALL _PSPRT_POS(ESI,EDI) -> EAX (1-base)
              Concat(s1, s2)    -> CALL _PSPRT_CONCAT(ESI,EDI) -> EAX
              Ord(c)            -> MOVZX EAX,BYTE PTR [c]
              Chr(n)            -> CALL _PSPRT_CHR -> EAX=ptr chaine 1 car
              IntToStr(n)       -> CALL _PSPRT_NUMTOSTR -> EAX=ptr
              StrToInt(s)       -> CALL _PSPRT_STRTONUM -> EAX=valeur
              UpCase(c)         -> inline CMP/SUB pour a-z -> A-Z
              LowerCase(s)      -> CALL _PSPRT_LOWERCASE -> EAX=ptr
              Trim(s)           -> CALL _PSPRT_TRIM -> EAX=ptr
              Delete(s, p, n)   -> CALL _PSPRT_DELETE (modifie en place)
              Insert(sub, s, p) -> CALL _PSPRT_INSERT (modifie en place)
            Procedures de conversion :
              Str(n, s)         -> _PSPRT_NUMTOSTR + copie dans s
              Val(s, n, code)   -> _PSPRT_STRTONUM + code d erreur
            Fonctions memoire :
              New(ptr)          -> HeapAlloc(GetProcessHeap, 0, size) -> EAX
              GetMem(ptr, size) -> HeapAlloc -> EAX
              Dispose(ptr)      -> HeapFree(GetProcessHeap, 0, ptr)
              FreeMem(ptr, sz)  -> HeapFree
              FillChar(v, n, c) -> REP STOSB (EDI=v, ECX=n, AL=c)
              Move(src, dst, n) -> REP MOVSB (ESI=src, EDI=dst, ECX=n)
            Fonctions mathematiques :
              Abs(n)            -> CDQ / XOR EAX,EDX / SUB EAX,EDX
              Sqr(n)            -> IMUL EAX,EAX
              Sqrt(n)           -> Newton-Raphson entier 32 bits
              Random / Random(n)-> LCG 32 bits (IMUL+ADD seed)
              Randomize         -> GetTickCount ou RDTSC pour seed
              Odd(n)            -> TEST EAX,1
              Inc(v[,n])        -> ADD [v],n (defaut n=1)
              Dec(v[,n])        -> SUB [v],n (defaut n=1)

  TODO 23 - GENERATION DE FICHIERS PE (.EXE) ET COFF (.OBJ)
            Mode par defaut (-exe implicite) : produire un fichier .EXE
              Generation directe du format PE (Portable Executable) :
              DOS Stub (MZ header + message 'This program requires Win32')
              PE Signature ('PE\0\0')
              COFF File Header (Machine=014Ch i386, NumberOfSections)
              Optional Header (PE32, AddressOfEntryPoint, ImageBase=00400000h,
                SectionAlignment=1000h, FileAlignment=200h,
                SizeOfImage, SizeOfHeaders, Subsystem=IMAGE_SUBSYSTEM_WINDOWS_CUI)
              Section .text : code executable (Characteristics=60000020h)
              Section .data : donnees initialisees (Characteristics=C0000040h)
              Section .rdata : table d importation (Import Directory)
              Import Directory : entree pour KERNEL32.DLL
                Import Lookup Table -> Hint/Name entries pour chaque API
                Import Address Table (IAT) patchee par le loader
                APIs importees : ExitProcess, GetStdHandle, WriteFile,
                  ReadFile, GetProcessHeap, HeapAlloc, HeapFree,
                  GetTickCount
              Relocalisation des adresses : calcul RVA pour chaque reference
              Alignement des sections sur FileAlignment (padding)
            Mode -obj : produire uniquement un fichier COFF .OBJ
              COFF Object File : File Header + Sections + Symbol Table
              Sections : .text (code), .data (donnees)
              Table des symboles COFF : noms publics et externes
              Table des relocalisations : fixups pour le linker
              Symboles EXTERNAL pour les API Win32 (resolution par linker)
            Mode -asm : produire un listing .ASM en plus du binaire
              Fichier texte MASM compatible (.386 / .MODEL FLAT)
              Commentaires descriptifs pour chaque section

  TODO 24 - RUNTIME MINIMAL WIN32
            Initialisation au demarrage (_PSPF_main) :
              CALL GetStdHandle(STD_OUTPUT_HANDLE=-11)
              MOV [_PSPRT_HSTDOUT], EAX
              CALL GetStdHandle(STD_INPUT_HANDLE=-10)
              MOV [_PSPRT_HSTDIN], EAX
            _PSPRT_PRINTSTR(ESI=ptr ASCIIZ) :
              Calculer longueur (REPNE SCASB)
              PUSH 0 / LEA EAX,[EBP-4] / PUSH EAX / PUSH ECX (len)
              PUSH ESI / PUSH [_PSPRT_HSTDOUT] / CALL WriteFile
            _PSPRT_NUMTOSTR(EAX=n, EDI=buf) :
              Entier signe 32 bits -> ASCII decimal dans NUMBUF
              Gestion du signe negatif (NEG + prefixe '-')
              Division successive par 10, stockage inverse
            _PSPRT_STRTONUM(ESI=str) -> EAX :
              ASCII decimal -> entier signe 32 bits
              Gestion du signe et des espaces en tete
            _PSPRT_STRLEN(ESI=str) -> EAX : longueur ASCIIZ
            _PSPRT_CONCAT(ESI=s1, EDI=s2) -> EAX=ptr STRBUF :
              Copier s1 puis s2 dans _PSPRT_STRBUF
            _PSPRT_STRCMP(ESI=s1, EDI=s2) -> EAX (signe) :
              Comparaison lexicographique octet par octet
            _PSPRT_CHR(AL=code) -> EAX=ptr CHRBUF :
              Caractere unique en chaine ASCIIZ de 1 octet
            _PSPRT_COPY(ESI=str, EBX=pos, ECX=len) -> EAX=ptr :
              Extraction de sous-chaine (1-base)
            _PSPRT_POS(ESI=sub, EDI=str) -> EAX :
              Recherche de sous-chaine (1-base, 0 si non trouve)
            _PSPRT_DELETE(ESI=str, EBX=pos, ECX=len) :
              Suppression en place dans la chaine
            _PSPRT_INSERT(ESI=sub, EDI=str, EBX=pos) :
              Insertion en place dans la chaine
            _PSPRT_LOWERCASE(ESI=str) -> EAX=ptr STRBUF :
              Conversion minuscules dans tampon
            _PSPRT_TRIM(ESI=str) -> EAX=ptr STRBUF :
              Suppression espaces debut/fin
            _PSPRT_SQRT(EAX=n) -> EAX : racine carree entiere Newton-Raphson
            _PSPRT_RANDOM -> EAX : LCG 32 bits (seed * 1103515245 + 12345)
            _PSPRT_RANDOMIZE : seed depuis GetTickCount
            _PSPRT_FILLCHAR(EDI=ptr, ECX=count, AL=val) : REP STOSB
            _PSPRT_MOVE(ESI=src, EDI=dst, ECX=count) : REP MOVSB
            _PSPRT_PANIC(ESI=msg) : ecrire message + PUSH 1 / CALL ExitProcess
            _PSPRT_PANIC_DIV0 : 'Runtime error: Division by zero'
            Donnees runtime dans .DATA :
              _PSPRT_HSTDOUT DD 0 / _PSPRT_HSTDIN DD 0
              _PSPRT_CRLF DB 13,10,0
              _PSPRT_TRUE_S DB 'TRUE',0 / _PSPRT_FALSE_S DB 'FALSE',0
              _PSPRT_STRBUF DB 512 DUP(0)
              _PSPRT_CHRBUF DB 0,0 / _PSPRT_NUMBUF DB 12 DUP(0)
              _PSPRT_SEED DD 0 / _PSPRT_DIV0MSG DB '...',0
            RuntimeEmitted : flag pour n emettre le runtime qu une seule fois

  TODO 25 - GENERATION FINALE ET FICHIERS EXEMPLES
            EmitClose : finaliser le fichier de sortie
              Mode ASM : END _PSPF_main dans _TEXT ENDS / .DATA ENDS
              Mode OBJ : ecrire les sections COFF et table des symboles
              Mode EXE : ecrire les sections PE, import table, padding
            Run : pipeline complet
              ParseArgs -> LexInit -> TplNextToken boucle ->
              ParseProgram (ou mode template implicite) ->
              EmitRuntime -> Finaliser sections -> Ecrire fichier
            Statistiques (-v) : lignes lues, symboles, erreurs, avertissements
            Compatibilite avec tous les exemples SAMPLES\PSP\ :
              hello.psp        (HTML + Write, boucle for, WriteLn)
              test_expr.psp    (expressions arithmetiques, comparaisons)
              test_var.psp     (variables, affectations, constantes)
              test_const.psp   (constantes nommees et typees)
              test_if.psp      (if/then/else, case/of, imbrication)
              test_case.psp    (case avec valeurs multiples, intervalles)
              test_loop.psp    (for/while/repeat, break, continue)
              test_func.psp    (fonctions, procedures, forward, exit)
              test_function.psp(fonctions avec Result, parametres var)
              test_types.psp   (types definis par l utilisateur)
              test_string.psp  (operations sur chaines, concatenation)
              test_str.psp     (fonctions de chaines Length/Copy/Pos)
              test_array.psp   (tableaux, acces par index, Length/Low/High)
              test_record.psp  (records, acces champs, with)
              test_enum.psp    (enumerations, Ord, case)
              test_scope.psp   (portees imbriquees, masquage de variables)
              test_write.psp   (Write/WriteLn multi-arguments, types mixtes)
              test_directives.psp (DEFINE/IFDEF/INCLUDE, conditionnels)
              test_include.psp (inclusion de fichiers $I)
              test_errors.psp  (gestion d erreurs, messages)
              test_runtime.psp (fonctions runtime, chaines, math)
              test_stdlib.psp  (fonctions standard Abs/Sqr/Random)
              test_sym.psp     (table des symboles, scopes)
              test_lex.psp     (tokens, commentaires, litteraux)
              test_expr11.psp  (expressions complexes, precedence)
              test_arith.psp   (arithmetique, division, modulo)
              calculcalciumcorrige.psp (fonction Real, calcul medical)
            Smoke tests : PSPCW32.EXE [-v] SAMPLES\PSP\*.psp

  ============================================================ *)

Program PSPCW32;

{$IFDEF FPC}
  {$MODE TP}
  {$H-}
{$ENDIF}
{$I-}

{ ============================================================
  CONSTANTES
  ============================================================ }
Const
  PSPCW32_VERSION = '1.0';
  PSPCW32_DATE    = '2026-03-07';

  { Limites internes }
  MAX_SYM       = {$IFDEF FPC}2048{$ELSE}100{$ENDIF};
  MAX_LABEL     = {$IFDEF FPC}2048{$ELSE}100{$ENDIF};
  MAX_SCOPE     = {$IFDEF FPC}64{$ELSE}32{$ENDIF};
  MAX_DATA      = {$IFDEF FPC}512{$ELSE}64{$ENDIF};
  MAX_TYPE      = {$IFDEF FPC}32{$ELSE}8{$ENDIF};
  MAX_PARAM     = {$IFDEF FPC}32{$ELSE}8{$ENDIF};
  MAX_LOOP_NEST = {$IFDEF FPC}16{$ELSE}8{$ENDIF};
  MAX_ERRORS    = {$IFDEF FPC}30{$ELSE}3{$ENDIF};
  MAX_STR       = {$IFDEF FPC}255{$ELSE}80{$ENDIF};
  MAX_INCLUDE   = {$IFDEF FPC}8{$ELSE}4{$ENDIF};     { profondeur max d inclusion }
  MAX_DEFINE    = {$IFDEF FPC}64{$ELSE}16{$ENDIF};    { nombre max de symboles de compilation }
  MAX_FIELD     = {$IFDEF FPC}32{$ELSE}16{$ENDIF};    { champs max par record }
  MAX_ENUM      = {$IFDEF FPC}64{$ELSE}16{$ENDIF};    { valeurs max par enumeration }
  MAX_WITH      = 8;     { profondeur max de with imbrique }
  STACK_SIZE    = 4096;  { taille pile Win32 }
  FRAME_WARN    = 512;   { seuil avertissement taille cadre (octets) }
  NEST_MAX      = 4;     { profondeur max imbrication proc/func }

  { Prefixes de nommage ASM }
  PSP_VAR_PFX   = '_PSP_';      { variable globale              }
  PSP_FN_PFX    = '_PSPF_';     { fonction / procedure          }
  PSP_STR_PFX   = '_PSPK_';     { constante chaine litterale    }
  PSP_RT_PFX    = '_PSPRT_';    { routine runtime               }
  PSP_LBL_PFX   = '_PSPL_';     { label de saut interne         }
  PSP_ARR_PFX   = '_PSPA_';     { tableau                       }
  PSP_REC_PFX   = '_PSPR_';     { record                        }
  PSP_ENUM_PFX  = '_PSPE_';     { enumeration                   }
  PSP_HTML_PFX  = '_PSPK_HTML_'; { fragment HTML literal         }
  PSP_EX_PFX    = '_PSPX_';     { exception handler             }

  { Codes de sortie }
  EXIT_OK    = 0;
  EXIT_ERROR = 1;
  EXIT_USAGE = 2;

  { Indices de types primitifs Pascal (32 bits) }
  TY_IDX_INTEGER = 0;   { entier 32 bits signe   }
  TY_IDX_WORD    = 1;   { entier 32 bits non signe }
  TY_IDX_BYTE    = 2;   { 8 bits non signe       }
  TY_IDX_CHAR    = 3;   { 8 bits caractere       }
  TY_IDX_BOOLEAN = 4;   { 0 | 1 dans AL/EAX     }
  TY_IDX_STRING  = 5;   { pointeur ASCIIZ 32 bits }
  TY_IDX_REAL    = 6;   { tronque en entier      }
  TY_IDX_POINTER = 7;   { pointeur generique 32 bits }
  TY_IDX_NIL     = 8;   { pointeur nul           }
  TY_IDX_TEXT    = 9;    { fichier texte (handle Win32) }
  TY_PRIM_COUNT  = 10;
  TY_UNKNOWN     = -1;

{ ============================================================
  TYPES
  ============================================================ }
Type
  TString = String[MAX_STR];

  { ---- Options de compilation ----------------------------- }
  TOptions = Record
    SrcFile   : TString;   { fichier source (.psp)                }
    OutFile   : TString;   { fichier de sortie (.exe/.obj/.asm)   }
    Verbose   : Boolean;   { -v : banniere et statistiques        }
    DebugMode : Boolean;   { -d : affichage de chaque token       }
    Warnings  : Boolean;   { -w : activer les avertissements      }
    EmitExe   : Boolean;   { produire un .EXE PE (defaut)         }
    EmitObj   : Boolean;   { -obj : produire uniquement un .OBJ   }
    EmitAsm   : Boolean;   { -asm : produire un listing .ASM      }
  End;

  { ---- Tokens Pascal / PSP ---------------------- }
  TTokenKind = (
    TK_EOF,            { fin de fichier                       }
    TK_INTEGER,        { literal entier 42 $FF                }
    TK_REAL,           { literal reel 3.14 1.5E3              }
    TK_STRING,         { literal chaine 'hello'               }
    TK_CHAR,           { literal caractere #65 #$41           }
    TK_IDENT,          { identificateur (non-mot-cle)         }
    TK_KEYWORD,        { mot-cle Pascal reconnu               }
    TK_OP,             { operateur := + - * / = <> < > etc.   }
    TK_PUNCT,          { ponctuation ; , ( ) [ ] . ..         }
    TK_HTML,           { texte HTML literal hors balises       }
    TK_PSP_OPEN,       { balise <% ouvrante                   }
    TK_PSP_CLOSE,      { balise %> fermante                   }
    TK_PSP_EXPR_OPEN,  { balise <%= (expression inline)       }
    TK_PSP_DIRECTIVE   { balise <%@ (directive de page)       }
  );

  TToken = Record
    Kind     : TTokenKind;
    Val      : TString;     { valeur textuelle brute           }
    IntVal   : LongInt;     { valeur entiere (TK_INTEGER)      }
    RealVal  : Real;        { valeur reelle (TK_REAL)          }
    Line     : Integer;     { ligne source (1-base)            }
    Col      : Integer;     { colonne source (1-base)          }
  End;

  { ---- Mode du template PSP --------------------- }
  TPSPMode = (TPL_HTML, TPL_CODE);

  { ---- Segment de donnees ------------ }
  TDataKind = (DK_DWORD, DK_BYTE, DK_STR, DK_ARRAY, DK_REC);

  TDataRec = Record
    LblName   : TString;
    Kind      : TDataKind;
    IntVal    : LongInt;
    StrVal    : TString;
    ElemCount : Integer;   { nombre d elements (DK_ARRAY)        }
    ElemSize  : Integer;   { taille d un element (DK_ARRAY)      }
    RecSize   : Integer;   { taille totale en octets (DK_REC)    }
  End;

  { ---- Valeurs d expression --------------------- }
  TExprKind = (
    EK_NONE,   { void / pas de valeur                       }
    EK_IMM,    { valeur immediate dans ImmVal                }
    EK_AX,     { valeur dans registre EAX                    }
    EK_MEM     { adresse memoire [EBP+Offset] ou [_PSP_x]   }
  );

  TExprVal = Record
    Kind    : TExprKind;
    ImmVal  : LongInt;
    TypeIdx : Integer;
    Offset  : Integer;
    SymIdx  : Integer;   { indice dans SymTab (-1 si pas lvalue) }
  End;

  { ---- Genre de type ----------------------------- }
  TTypeKind = (
    TKP_INTEGER,   { entier 32 bits signe                    }
    TKP_WORD,      { entier 32 bits non signe                 }
    TKP_BYTE,      { 8 bits non signe                         }
    TKP_CHAR,      { 8 bits caractere                         }
    TKP_BOOLEAN,   { 0 ou 1 dans AL, etendu EAX               }
    TKP_STRING,    { pointeur ASCIIZ dans EAX                  }
    TKP_REAL,      { tronque en entier 32 bits                 }
    TKP_ARRAY,     { tableau (BaseTypeIdx = type element)      }
    TKP_RECORD,    { enregistrement (FieldCount champs)        }
    TKP_ENUM,      { enumeration (EnumCount valeurs)           }
    TKP_SUBRANGE,  { sous-intervalle (Lo..Hi)                  }
    TKP_POINTER,   { pointeur generique 32 bits                }
    TKP_NIL,       { pointeur nul                              }
    TKP_TEXT,      { fichier texte (handle Win32)              }
    TKP_VOID       { procedure, pas de valeur de retour        }
  );

  { ---- Champ de record --------------------------- }
  TFieldRec = Record
    Name    : TString;
    TypeIdx : Integer;
    Offset  : Integer;  { decalage en octets dans le record }
  End;

  { ---- Valeur d enumeration ---------------------- }
  TEnumValRec = Record
    Name  : TString;
    Value : Integer;
  End;

  { ---- Enregistrement de type -------------------- }
  TTypeRec = Record
    Kind        : TTypeKind;
    Size        : Integer;     { taille en octets                   }
    BaseTypeIdx : Integer;     { type de base (pointer/array/sub)   }
    Lo          : LongInt;     { borne inf (subrange/array)         }
    Hi          : LongInt;     { borne sup (subrange/array)         }
    FieldCount  : Integer;     { nombre de champs (record)          }
    Fields      : Array[0..MAX_FIELD - 1] Of TFieldRec;
    EnumCount   : Integer;     { nombre de valeurs (enum)           }
    Enums       : Array[0..MAX_ENUM - 1] Of TEnumValRec;
  End;

  { ---- Categorie de symbole ---------------------- }
  TSymCat = (
    SC_VAR,          { variable globale ou locale           }
    SC_CONST,        { constante non-typee (substitution)   }
    SC_TYPED_CONST,  { constante typee (en DATA)            }
    SC_PARAM,        { parametre par valeur                 }
    SC_VARPARAM,     { parametre var (par reference)        }
    SC_FUNC,         { fonction                             }
    SC_PROC,         { procedure                            }
    SC_TYPE,         { nom de type                          }
    SC_FIELD,        { champ de record                      }
    SC_ENUM_VAL,     { valeur d enumeration                 }
    SC_LABEL         { label nomme                          }
  );

  { ---- Enregistrement symbole -------------------- }
  TSymRec = Record
    Name        : TString;  { nom original Pascal (minuscule)    }
    MangledName : TString;  { nom ASM mangled (_PSP_xxx etc.)    }
    Cat         : TSymCat;  { categorie (var/const/func etc.)    }
    TypeIdx     : Integer;  { indice dans TypeTab (TY_IDX_*)     }
    Offset      : Integer;  { offset cadre local (EBP+n)         }
    ScopeLevel  : Integer;  { profondeur de portee (0=global)    }
    ScopeId     : Integer;  { identifiant unique de portee       }
    IsForward   : Boolean;  { declaration forward non resolue    }
    IsLocal     : Boolean;  { True si variable locale            }
    ImmVal      : LongInt;  { valeur immediate (SC_CONST)        }
    DataIdx     : Integer;  { index DataTab (SC_TYPED_CONST)     }
    ParamCnt    : Integer;  { nb params (SC_FUNC/SC_PROC)        }
    VarParamMask: LongInt;  { bitmask var params (bit i=1)       }
  End;

{ ============================================================
  VARIABLES GLOBALES
  ============================================================ }
Var
  { Options }
  Opts : TOptions;

  { Compteurs generaux }
  ErrorCount : Integer;
  WarnCount  : Integer;
  TotalLines : LongInt;
  TotalSyms  : Integer;

  { Emetteur ASM (pour Cleanup) }
  OutF     : Text;
  OutFOpen : Boolean;

  { Lexeur }
  LexSrcF   : Text;
  LexOpened : Boolean;
  LexLine   : String;
  LexLineNo : Integer;
  LexColNo  : Integer;
  LexEOF    : Boolean;
  CurToken  : TToken;

  { Analyseur de template }
  TplMode      : TPSPMode;
  TplHtmlBuf   : TString;
  TplPending   : TTokenKind;
  TplHtmlCount : Integer;

  { Segment de donnees }
  DataTab      : Array[0..MAX_DATA - 1] Of TDataRec;
  DataCount    : Integer;
  LabelGenSeq  : Integer;

  { Table des symboles }
  SymTab        : Array[0..MAX_SYM - 1] Of TSymRec;
  SymCount      : Integer;
  CurScopeLevel : Integer;
  CurScopeId    : Integer;
  ScopeIdSeq    : Integer;

  { Table des types }
  TypeTab   : Array[0..MAX_TYPE - 1] Of TTypeRec;
  TypeCount : Integer;

  { Variables et affectations }
  CurFrameOffset   : Integer;  { offset courant dans le cadre local (negatif) }
  PendingAssignName : TString; { nom ident en attente (lookahead ParseVarDecl) }
  HasPendingAssign  : Boolean; { True si une affectation a ete detectee }

  { Pile de boucles pour break/continue }
  LoopBreakLbl    : Array[0..MAX_LOOP_NEST - 1] Of TString;
  LoopContLbl     : Array[0..MAX_LOOP_NEST - 1] Of TString;
  LoopTop         : Integer;  { sommet de la pile (-1 = vide) }

  { Fonctions et procedures }
  CurFuncName     : TString;  { nom de la fonction en cours ('' si aucune) }
  CurFuncRetOfs   : Integer;  { offset de la valeur de retour [EBP+n] }
  CurRetLabel     : TString;  { label de retour (_PSPL_RET_N) pour Exit }
  CurNestLevel    : Integer;  { profondeur d imbrication proc/func }
  CurParamBytes   : Integer;  { taille des parametres pour RET n }
  MainBodyEmitted : Boolean;  { True si _PSPL_MAINBODY deja emis }
  RuntimeEmitted  : Boolean;  { True si routines runtime deja emises }

  { Pile with pour records }
  WithSymIdx      : Array[0..MAX_WITH - 1] Of Integer;  { symidx du record }
  WithTop         : Integer;  { sommet de la pile (-1 = vide) }

  { Directives et inclusions }
  IncSavedFName   : Array[0..MAX_INCLUDE - 1] Of TString; { nom fichier empile }
  IncSavedFLine   : Array[0..MAX_INCLUDE - 1] Of Integer;{ ligne dans fichier }
  IncSavedLine    : Array[0..MAX_INCLUDE - 1] Of String; { ligne courante  }
  IncSavedLineNo  : Array[0..MAX_INCLUDE - 1] Of Integer;{ numero de ligne }
  IncSavedColNo   : Array[0..MAX_INCLUDE - 1] Of Integer;{ colonne         }
  IncSavedEOF     : Array[0..MAX_INCLUDE - 1] Of Boolean;{ EOF sauvegarde  }
  LexSrcFName     : TString;  { nom du fichier source courant }
  IncTop          : Integer;  { sommet pile inclusion (-1 = vide) }
  DefineTab       : Array[0..MAX_DEFINE - 1] Of TString; { symboles defines }
  DefineCount     : Integer;  { nombre de defines actifs }
  CompilerMode    : TString;  { 'TP' ou 'FPC' }
  ContentTypeLbl  : TString;  { label content-type ou '' }

{ ============================================================
  FORWARD DECLARATIONS
  ============================================================ }
{ Utilitaires chaines - TODO 01 }
Function  StrLowerCase(Const S : TString) : TString; Forward;
Function  StrUpperCase(Const S : TString) : TString; Forward;
Function  IntToStr(N : LongInt) : TString; Forward;
Function  EBPOfs(Ofs : Integer) : TString; Forward;
Function  StrToIntDef(Const S : TString; Def : LongInt) : LongInt; Forward;
{ Messages - TODO 01 }
Procedure FatalError(Const Msg : TString); Forward;
Procedure WarnMsg(Const Msg : TString); Forward;
Procedure ErrorMsg(Const Msg : TString); Forward;
Procedure Expect(Const Expected : TString); Forward;
Procedure SkipTo; Forward;
{ Lexeur - TODO 02 }
Procedure LexInit;       Forward;
Procedure LexClose;      Forward;
Procedure LexNextLine;   Forward;
Procedure LexNextToken;  Forward;
Procedure LexScanIdent;  Forward;
Procedure LexScanNumber; Forward;
Procedure LexScanString; Forward;
Procedure LexScanCharLit;Forward;
Function  IsKeyword(Const S : TString) : Boolean; Forward;
Function  IsIdentStart(Ch : Char) : Boolean; Forward;
Function  IsIdentCont(Ch : Char) : Boolean; Forward;
Function  IsHexDigit(Ch : Char) : Boolean; Forward;
Function  HexVal(Ch : Char) : Integer; Forward;
Procedure PrintToken(Const T : TToken); Forward;
Procedure LexSkipBraceComment; Forward;
Procedure LexSkipParenStarComment; Forward;
Procedure LexSkipLineComment; Forward;
Procedure LexScanHexNumber; Forward;
Procedure LexSkipCondFalse; Forward;
{ Directives et inclusions - TODO 20 }
Procedure LexHandleDollarDirective; Forward;
Procedure IncludePush(Const FileName : TString); Forward;
Procedure IncludePop; Forward;
Function  DefineDefined(Const Name : TString) : Boolean; Forward;
Procedure DefineAdd(Const Name : TString); Forward;
Procedure DefineRemove(Const Name : TString); Forward;
Procedure ParsePSPDirective; Forward;
{ Analyseur de template - TODO 19 }
Procedure TplInit;       Forward;
Procedure TplClose;      Forward;
Procedure TplEmitHtml;   Forward;
Procedure TplEmitPSPOpen(Kind : TTokenKind); Forward;
Procedure TplNextToken;  Forward;
{ Segment de donnees et litteraux - TODO 03 / 08 }
Function  LabelGen : TString; Forward;
Function  DataAdd(Const Lbl : TString; Kind : TDataKind;
                 AIntVal : LongInt; Const AStrVal : TString) : Integer; Forward;
Function  DataAddStr(Const S : TString) : TString; Forward;
Function  DataAddDWord(Const Lbl : TString; AIntVal : LongInt) : Integer; Forward;
Function  DataAddByte(Const Lbl : TString; AIntVal : LongInt) : Integer; Forward;
Function  DataAddArray(Const Lbl : TString;
                ECount, ESz : Integer) : Integer; Forward;
Function  DataAddRec(Const Lbl : TString;
                RSz : Integer) : Integer; Forward;
Function  DataAddHtml(Const Html : TString) : TString; Forward;
Procedure EmitRaw(Const S : String); Forward;
Procedure EmitDataSeg; Forward;
Procedure LitEval(Const T : TToken; Var Res : TExprVal); Forward;
Procedure ParseConstDecl; Forward;
{ Table des symboles - TODO 05 }
Function  SymMangle(Const Name : TString; Cat : TSymCat) : TString; Forward;
Function  SymAdd(Const Name : TString; Cat : TSymCat;
               TIdx : Integer) : Integer; Forward;
Function  SymFind(Const Name : TString) : Integer; Forward;
Function  SymFindInScope(Const Name : TString;
               Level : Integer) : Integer; Forward;
Procedure SymEnterScope; Forward;
Procedure SymLeaveScope; Forward;
Procedure SymInit; Forward;
{ Systeme de types - TODO 06 }
Procedure TypeInit; Forward;
Function  TypeSizeof(TIdx : Integer) : Integer; Forward;
Function  TypeCompatible(T1, T2 : Integer) : Boolean; Forward;
Function  TypeCoerce(SrcType, DstType : Integer) : Integer; Forward;
Function  TypeResolve(Const Name : TString) : Integer; Forward;
Function  TypeIsOrdinal(TIdx : Integer) : Boolean; Forward;
Function  TypeIsNumeric(TIdx : Integer) : Boolean; Forward;
Function  TypeIsPointer(TIdx : Integer) : Boolean; Forward;
{ Emetteur ASM - TODO 07 }
Procedure EmitComment(Const S : TString); Forward;
Procedure EmitLabel(Const Lbl : TString); Forward;
Procedure EmitInstr(Const Mnem : TString); Forward;
Procedure EmitInstrA(Const Mnem, A1 : TString); Forward;
Procedure EmitInstrAB(Const Mnem, A1, A2 : TString); Forward;
Procedure EmitBlankLine; Forward;
Function  NewLabel : TString; Forward;
Procedure EmitHeader; Forward;
Procedure EmitFooter; Forward;
Procedure EmitProlog(FrameSize : Integer); Forward;
Procedure EmitEpilog(ParamBytes : Integer); Forward;
Procedure EmitPush(Const Reg : TString); Forward;
Procedure EmitPop(Const Reg : TString); Forward;
Procedure EmitMov(Const Dst, Src : TString); Forward;
Procedure EmitCall(Const Target : TString); Forward;
Procedure EmitJmp(Const Target : TString); Forward;
Procedure EmitJmpCond(Const Cond, Target : TString); Forward;
Procedure EmitCoerce(SrcType, DstType : Integer); Forward;
{ Operateurs et expressions - TODO 04 / 10 / 11 }
Function  OpPrec(Const Op : TString) : Integer; Forward;
Procedure ExprMakeImm(V : LongInt; TIdx : Integer; Var R : TExprVal); Forward;
Procedure ExprFlushToEAX(Var E : TExprVal); Forward;
Procedure ParseCallArgs(FuncIdx : Integer); Forward;
Procedure ParsePrimary(Var Res : TExprVal); Forward;
Procedure ParseUnary(Var Res : TExprVal); Forward;
Procedure ParseExprPrec(MinPrec : Integer; Var Res : TExprVal); Forward;
Procedure ParseExpr(Var Res : TExprVal); Forward;
{ Variables et affectations - TODO 09 }
Function  ExprAddrOf(SIdx : Integer) : TString; Forward;
Procedure ExprStore(SIdx : Integer); Forward;
Procedure ExprLoad(SIdx : Integer; Var E : TExprVal); Forward;
Function  DeclAllocGlobal(Const Name : TString;
                TIdx : Integer) : Integer; Forward;
Function  DeclAllocLocal(Const Name : TString;
                TIdx : Integer) : Integer; Forward;
Procedure ParseVarDecl; Forward;
Procedure ParseAssignment(Const VarName : TString); Forward;
{ Impression selon type - TODO 10 }
Procedure EmitPrintEAX(TypeIdx : Integer); Forward;
{ Write/WriteLn et emission HTML - TODO 10 / 12 / 19 }
Procedure ParseWriteStmt(IsWriteLn : Boolean); Forward;
Procedure EmitHtmlFragment(Const Html : TString); Forward;
Procedure EmitExprInline; Forward;
{ If/Then/Else, Case/Of, Blocs - TODO 13 }
Procedure ParseStatement; Forward;
Procedure ParseBlock; Forward;
Procedure ParseIfStmt; Forward;
Procedure ParseCaseStmt; Forward;
{ Boucles - TODO 14 }
Procedure ParseForStmt; Forward;
Procedure ParseWhileStmt; Forward;
Procedure ParseRepeatStmt; Forward;
{ Fonctions et procedures - TODO 18 }
Function ParseParamList : Integer; Forward;
Procedure ParseFuncOrProc(IsFunc : Boolean); Forward;
Procedure ParseFuncDecl; Forward;
Procedure ParseProcDecl; Forward;
{ Types definis et enumerations - TODO 06 / 17 }
Procedure ParseTypeDecl; Forward;
Procedure ParseIncDecStmt(IsInc : Boolean); Forward;
{ Enregistrements - TODO 16 }
Procedure ParseWithStmt; Forward;
{ Exceptions - TODO 21 }
Procedure ParseTryExcept; Forward;

{ ============================================================
  STUBS POUR DECLARATIONS FORWARD (a implementer dans les TODOs suivants)
  ============================================================ }

{ ============================================================
  TODO 02 - LEXEUR PSP (TOKENS PASCAL ET BALISES HTML) [IMPLEMENTE]
  ============================================================ }

{ ---- IsKeyword : teste si S est un mot-cle Pascal ---------- }
{ Comparaison insensible a la casse                            }
Function IsKeyword(Const S : TString) : Boolean;
Var
  L : TString;
Begin
  L := StrLowerCase(S);
  IsKeyword :=
    (L = 'program')   Or (L = 'begin')     Or (L = 'end')       Or
    (L = 'var')        Or (L = 'const')     Or (L = 'type')      Or
    (L = 'if')         Or (L = 'then')      Or (L = 'else')      Or
    (L = 'while')      Or (L = 'do')        Or (L = 'for')       Or
    (L = 'to')         Or (L = 'downto')    Or (L = 'repeat')    Or
    (L = 'until')      Or (L = 'case')      Or (L = 'of')        Or
    (L = 'function')   Or (L = 'procedure') Or (L = 'forward')   Or
    (L = 'array')      Or (L = 'record')    Or (L = 'string')    Or
    (L = 'integer')    Or (L = 'boolean')   Or (L = 'char')      Or
    (L = 'byte')       Or (L = 'word')      Or (L = 'real')      Or
    (L = 'nil')        Or (L = 'true')      Or (L = 'false')     Or
    (L = 'not')        Or (L = 'and')       Or (L = 'or')        Or
    (L = 'xor')        Or (L = 'div')       Or (L = 'mod')       Or
    (L = 'shl')        Or (L = 'shr')       Or (L = 'in')        Or
    (L = 'with')       Or (L = 'uses')      Or (L = 'write')     Or
    (L = 'writeln')    Or (L = 'read')      Or (L = 'readln')    Or
    (L = 'break')      Or (L = 'continue')  Or (L = 'exit')      Or
    (L = 'halt')       Or (L = 'try')       Or (L = 'except')    Or
    (L = 'finally')    Or (L = 'raise')     Or (L = 'result');
End;

{ ---- PrintToken : affichage debug d un token --------------- }
Procedure PrintToken(Const T : TToken);
Var
  S : TString;
Begin
  If Not Opts.DebugMode Then Exit;
  Write('  [', T.Line, ',', T.Col, '] ');
  Case T.Kind Of
    TK_EOF           : Write('EOF');
    TK_INTEGER       : Write('INT(', T.IntVal, ')');
    TK_REAL          : Write('REAL(', T.Val, ')');
    TK_STRING        : Write('STR(''', T.Val, ''')');
    TK_CHAR          : Write('CHAR(#', T.IntVal, ')');
    TK_IDENT         : Write('IDENT(', T.Val, ')');
    TK_KEYWORD       : Write('KW(', T.Val, ')');
    TK_OP            : Write('OP(', T.Val, ')');
    TK_PUNCT         : Write('PUNCT(', T.Val, ')');
    TK_HTML          : Begin
                         S := T.Val;
                         If Length(S) > 40 Then
                           S := Copy(S, 1, 37) + '...';
                         Write('HTML("', S, '")');
                       End;
    TK_PSP_OPEN      : Write('PSP_OPEN');
    TK_PSP_CLOSE     : Write('PSP_CLOSE');
    TK_PSP_EXPR_OPEN : Write('PSP_EXPR');
    TK_PSP_DIRECTIVE : Write('PSP_DIR');
  End;
  WriteLn;
End;

{ ---- LexNextLine : lire la prochaine ligne source ----------- }
Procedure LexNextLine;
Begin
  If LexEOF Then Exit;
  If EOF(LexSrcF) Then
  Begin
    { Si on est dans un fichier inclus, depiler }
    If IncTop >= 0 Then
    Begin
      IncludePop;
      Exit;  { reprendre la lecture dans le fichier parent }
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

{ ---- Fonctions de test sur les caracteres ------------------- }
Function IsIdentStart(Ch : Char) : Boolean;
Begin
  IsIdentStart := ((Ch >= 'A') And (Ch <= 'Z')) Or
                  ((Ch >= 'a') And (Ch <= 'z')) Or
                  (Ch = '_');
End;

Function IsIdentCont(Ch : Char) : Boolean;
Begin
  IsIdentCont := IsIdentStart(Ch) Or ((Ch >= '0') And (Ch <= '9'));
End;

Function IsHexDigit(Ch : Char) : Boolean;
Begin
  IsHexDigit := ((Ch >= '0') And (Ch <= '9')) Or
                ((Ch >= 'A') And (Ch <= 'F')) Or
                ((Ch >= 'a') And (Ch <= 'f'));
End;

Function HexVal(Ch : Char) : Integer;
Begin
  If (Ch >= '0') And (Ch <= '9') Then HexVal := Ord(Ch) - Ord('0')
  Else If (Ch >= 'A') And (Ch <= 'F') Then HexVal := Ord(Ch) - Ord('A') + 10
  Else HexVal := Ord(Ch) - Ord('a') + 10;
End;

{ ---- LexSkipBraceComment : sauter accolade-commentaire ------ }
{ Si le premier caractere apres la accolade ouvrante est $, on   }
{ dispatche vers LexHandleDollarDirective pour les directives.   }
Procedure LexSkipBraceComment;
Begin
  { Detecter dollar-directive }
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

{ ---- LexSkipParenStarComment : sauter paren-star comment ---- }
Procedure LexSkipParenStarComment;
Begin
  Inc(LexColNo); Inc(LexColNo); { sauter ( et * }
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

{ ---- LexSkipLineComment : sauter // ... fin de ligne -------- }
Procedure LexSkipLineComment;
Begin
  LexColNo := Length(LexLine) + 1;
End;

{ ============================================================
  TODO 20 - DIRECTIVES DE COMPILATION [IMPLEMENTE]
  ============================================================ }
{ La totalite de ce TODO est implementee dans la section
  TODO 02 (LexHandleDollarDirective, LexSkipCondFalse,
  DefineDefined, DefineAdd, DefineRemove, IncludePush,
  IncludePop).
  - $I/$INCLUDE : IncludePush sauvegarde l etat du lexeur
    (pile MAX_INCLUDE niveaux), ouvre le fichier inclus ;
    IncludePop restaure le fichier parent.
    LexNextLine depile automatiquement en fin de fichier inclus.
  - $DEFINE/$UNDEF : DefineAdd/DefineRemove gerent
    DefineTab[0..MAX_DEFINE-1] en majuscules.
  - $IFDEF/$IFNDEF/$ELSE/$ENDIF : LexHandleDollarDirective
    teste DefineDefined et appelle LexSkipCondFalse pour
    sauter les branches fausses, avec imbrication supportee.
  - $MODE TP|FPC : CompilerMode := Arg (reconnu, pas d effet).
  - LexSkipBraceComment detecte les accolades commencant par
    $ et dispatche vers LexHandleDollarDirective.            }

{ ---- DefineDefined : teste si un symbole est defini --------- }
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

{ ---- DefineAdd : ajouter un symbole de compilation ---------- }
Procedure DefineAdd(Const Name : TString);
Var
  N : TString;
Begin
  N := StrUpperCase(Name);
  If DefineDefined(N) Then Exit;  { deja defini }
  If DefineCount >= MAX_DEFINE Then
  Begin
    WarnMsg('trop de symboles $DEFINE');
    Exit;
  End;
  DefineTab[DefineCount] := N;
  Inc(DefineCount);
End;

{ ---- DefineRemove : supprimer un symbole de compilation ----- }
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

{ ---- IncludePush : empiler le fichier courant et ouvrir un include }
Procedure IncludePush(Const FileName : TString);
Var
  FullPath : TString;
Begin
  If IncTop >= MAX_INCLUDE - 1 Then
  Begin
    WarnMsg('profondeur d''inclusion maximale atteinte');
    Exit;
  End;
  { Sauvegarder l etat du lexeur }
  Inc(IncTop);
  IncSavedFName[IncTop]  := LexSrcFName;
  IncSavedFLine[IncTop]  := LexLineNo;
  IncSavedLine[IncTop]   := LexLine;
  IncSavedLineNo[IncTop] := LexLineNo;
  IncSavedColNo[IncTop]  := LexColNo;
  IncSavedEOF[IncTop]    := LexEOF;
  { Fermer le fichier courant avant d ouvrir l include }
  Close(LexSrcF);
  { Ouvrir le fichier inclus }
  FullPath := FileName;
  {$I-}
  Assign(LexSrcF, FullPath);
  Reset(LexSrcF);
  {$I+}
  If IOResult <> 0 Then
  Begin
    WarnMsg('impossible d''ouvrir le fichier include: ' + FullPath);
    { Rouvrir le fichier precedent }
    Assign(LexSrcF, IncSavedFName[IncTop]);
    Reset(LexSrcF);
    Dec(IncTop);
    Exit;
  End;
  LexSrcFName := FullPath;
  LexOpened := True;
  LexLine   := '';
  LexLineNo := 0;
  LexColNo  := 1;
  LexEOF    := False;
  LexNextLine;
End;

{ ---- IncludePop : depiler et restaurer le fichier precedent -- }
Procedure IncludePop;
Var
  I : Integer;
  Dummy : String;
Begin
  If IncTop < 0 Then Exit;
  Close(LexSrcF);
  { Rouvrir le fichier precedent et avancer jusqu a la bonne ligne }
  Assign(LexSrcF, IncSavedFName[IncTop]);
  Reset(LexSrcF);
  For I := 1 To IncSavedFLine[IncTop] Do
  Begin
    If Not EOF(LexSrcF) Then
      ReadLn(LexSrcF, Dummy);
  End;
  LexSrcFName := IncSavedFName[IncTop];
  LexLine   := IncSavedLine[IncTop];
  LexLineNo := IncSavedLineNo[IncTop];
  LexColNo  := IncSavedColNo[IncTop];
  LexEOF    := IncSavedEOF[IncTop];
  Dec(IncTop);
End;

(* ---- LexSkipCondFalse : sauter le code dans un IFDEF faux --- *)
(* Saute jusqu a trouver ELSE ou ENDIF au meme niveau            *)
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
        If (Dir = 'IFDEF') Or (Dir = 'IFNDEF') Then
          Inc(Depth)
        Else If Dir = 'ENDIF' Then
        Begin
          Dec(Depth);
          If Depth = 0 Then
          Begin
            (* Trouver l accolade fermante *)
            While (P <= Length(LexLine)) And (LexLine[P] <> '}') Do
              Inc(P);
            LexColNo := P + 1;
            Exit;
          End;
        End
        Else If (Dir = 'ELSE') And (Depth = 1) Then
        Begin
          { $ELSE au meme niveau : on commence a compiler }
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

(* ---- LexHandleDollarDirective : traiter dollar-directives -- *)
(* Appelee quand LexColNo pointe sur accolade et le char suivant *)
(* est $. Gere I, INCLUDE, DEFINE, UNDEF, IFDEF, IFNDEF,        *)
(* ELSE, ENDIF, MODE. Les autres sont ignores.                   *)
Procedure LexHandleDollarDirective;
Var
  Dir  : TString;
  Arg  : TString;
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
  { Sauter espaces }
  While (LexColNo <= Length(LexLine)) And
        (LexLine[LexColNo] = ' ') Do
    Inc(LexColNo);
  (* Lire l argument jusqu a accolade fermante *)
  Arg := '';
  While (LexColNo <= Length(LexLine)) And
        (LexLine[LexColNo] <> '}') Do
  Begin
    Arg := Arg + LexLine[LexColNo];
    Inc(LexColNo);
  End;
  { Supprimer espaces de fin de l argument }
  While (Length(Arg) > 0) And (Arg[Length(Arg)] = ' ') Do
    Delete(Arg, Length(Arg), 1);
  (* Consommer accolade fermante *)
  If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '}') Then
    Inc(LexColNo);

  { Dispatcher }
  If (Dir = 'I') Or (Dir = 'INCLUDE') Then
  Begin
    { Supprimer quotes eventuelles autour du nom de fichier }
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
      { Condition vraie : on ne fait rien, le code suivant sera compile }
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
  Else If Dir = 'ELSE' Then
  Begin
    { On est dans la branche vraie d un $IFDEF, sauter jusqu a $ENDIF }
    LexSkipCondFalse;
  End
  Else If Dir = 'ENDIF' Then
  Begin
    { Fin de bloc conditionnel, rien a faire }
  End
  Else If Dir = 'MODE' Then
  Begin
    Arg := StrUpperCase(Arg);
    If (Arg = 'TP') Or (Arg = 'FPC') Then
      CompilerMode := Arg
    Else
      WarnMsg('mode inconnu: ' + Arg + ' (TP ou FPC attendu)');
  End;
  { Autres directives : ignorees silencieusement }
End;

{ ---- ParsePSPDirective : traiter <%@ ... %> ------------------ }
{ Appelee quand CurToken = TK_PSP_DIRECTIVE. Parse les attributs  }
{ ContentType=xxx, Include file="xxx", CodePage=xxx               }
Procedure ParsePSPDirective;
Var
  AttrName  : TString;
  AttrVal   : TString;
  Lbl       : TString;
Begin
  TplNextToken;  { consommer <%@ }
  While (CurToken.Kind <> TK_EOF) And
        (CurToken.Kind <> TK_PSP_CLOSE) Do
  Begin
    If CurToken.Kind = TK_IDENT Then
    Begin
      AttrName := StrLowerCase(CurToken.Val);
      TplNextToken;
      { Consommer = }
      If (CurToken.Kind = TK_OP) And (CurToken.Val = '=') Then
        TplNextToken;
      { Lire la valeur : peut etre une chaine ou un ident/keyword }
      AttrVal := '';
      If CurToken.Kind = TK_STRING Then
      Begin
        AttrVal := CurToken.Val;
        TplNextToken;
      End
      Else
      Begin
        { Lire jusqu a un espace, %> ou fin de ligne }
        While (CurToken.Kind <> TK_EOF) And
              (CurToken.Kind <> TK_PSP_CLOSE) And
              (CurToken.Kind <> TK_IDENT) Do
        Begin
          AttrVal := AttrVal + CurToken.Val;
          TplNextToken;
        End;
        If Length(AttrVal) = 0 Then
        Begin
          AttrVal := CurToken.Val;
          TplNextToken;
        End;
      End;

      { Dispatcher l attribut }
      If AttrName = 'contenttype' Then
      Begin
        { Generer un label pour le content-type }
        Lbl := PSP_STR_PFX + 'CT';
        DataAdd(Lbl, DK_STR, 0,
          'Content-Type: ' + AttrVal + #13#10#13#10);
        ContentTypeLbl := Lbl;
      End
      Else If AttrName = 'include' Then
      Begin
        { Supprimer le mot file= si present }
        If Length(AttrVal) > 0 Then
          IncludePush(AttrVal)
        Else
          WarnMsg('nom de fichier attendu dans <%@ Include %>');
      End
      Else If AttrName = 'codepage' Then
        WarnMsg('CodePage=' + AttrVal + ' ignore (pas de support Unicode)')
      Else
        WarnMsg('directive PSP inconnue: ' + AttrName);
    End
    { Gerer Include file="..." ou page language="..." }
    Else If (CurToken.Kind = TK_KEYWORD) Then
    Begin
      AttrName := StrLowerCase(CurToken.Val);
      TplNextToken;
      { Ignorer les keywords non reconnus, avancer }
    End
    Else
      TplNextToken;
  End;
  { Consommer %> }
  If CurToken.Kind = TK_PSP_CLOSE Then
    TplNextToken;
End;

{ ---- LexScanIdent : scanner un identificateur ou mot-cle --- }
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
  CurToken.Val    := S;
  CurToken.IntVal := 0;
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

{ ---- LexScanNumber : scanner un litteral numerique ---------- }
{ Entiers decimaux, hexadecimaux ($FF), reels (3.14, 1.5E3)    }
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

  { Scanner la partie entiere decimale }
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
    Inc(LexColNo); { sauter point }
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
    Else If FltVal < -2147483648.0 Then N := -2147483648
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

{ ---- LexScanHexNumber : scanner un entier hexadecimal $FF -- }
Procedure LexScanHexNumber;
Var
  N : LongInt;
Begin
  Inc(LexColNo); { sauter $ }
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

{ ---- LexScanString : chaine Pascal entre quotes simples ---- }
{ Gere le doublement de quote : 'l''echo' -> l'echo            }
Procedure LexScanString;
Var
  S  : TString;
  Ch : Char;
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
  CurToken.Kind    := TK_STRING;
  CurToken.Val     := S;
  CurToken.IntVal  := 0;
  CurToken.RealVal := 0.0;
  { Si chaine de longueur 1, stocker aussi le code ASCII }
  If Length(S) = 1 Then
    CurToken.IntVal := Ord(S[1]);
End;

{ ---- LexScanCharLit : caractere #nn ou #$nn ----------------- }
Procedure LexScanCharLit;
Var
  V : LongInt;
  S : TString;
Begin
  S := '';
  { Scanner une sequence de #nn segments et concatener }
  While (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '#') Do
  Begin
    Inc(LexColNo); { sauter # }
    V := 0;
    If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '$') Then
    Begin
      Inc(LexColNo); { sauter $ }
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
      If LexLine[LexColNo] = '''' Then
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
          S := S + LexLine[LexColNo];
        Inc(LexColNo);
      End;
    End;
    { Peut etre suivi d un autre #nn }
    If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '#') Then
    Begin
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

{ ---- LexInit / LexClose ------------------------------------ }
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
  { Lire la premiere ligne }
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

{ ---- LexNextToken : scanner principal ----------------------- }
Procedure LexNextToken;
Var
  Ch : Char;
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

    { Commentaire // ligne }
    Else If (Ch = '/') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '/') Then
    Begin
      LexSkipLineComment;
    End

    { Commentaire accolade - ne pas confondre avec dollar-directives }
    Else If Ch = '{' Then
    Begin
      LexSkipBraceComment;
    End

    { Commentaire ( star ... star ) ou operateur ( }
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

    { Caractere literal #nn }
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

    { Balise fermante %> (geree ici en contexte code Pascal) }
    Else If (Ch = '%') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '>') Then
    Begin
      CurToken.Kind := TK_PSP_CLOSE;
      CurToken.Val  := '%>';
      Inc(LexColNo, 2);
      Scanning := False;
    End

    { Caractere inconnu : avancer et signaler }
    Else
    Begin
      WarnMsg('caractere inattendu: ' + Ch + ' (ord=' + IntToStr(Ord(Ch)) + ')');
      Inc(LexColNo);
    End;
  End;

  PrintToken(CurToken);
End;

{ ============================================================
  ANALYSEUR DE TEMPLATE PSP
  ============================================================ }

{ ---- TplInit : initialiser l analyseur de template --------- }
Procedure TplInit;
Begin
  TplMode      := TPL_HTML;
  TplHtmlBuf   := '';
  TplPending   := TK_EOF;
  TplHtmlCount := 0;
End;

{ ---- TplClose : finaliser l analyseur de template ---------- }
Procedure TplClose;
Begin
  If TplMode = TPL_CODE Then
    WarnMsg('fin de fichier atteinte en mode code (balise %> manquante ?)');
End;

{ ---- TplEmitHtml : emettre le buffer HTML comme token ------- }
{ Procedure interne utilisee par TplNextToken                   }
Procedure TplEmitHtml;
Begin
  CurToken.Kind    := TK_HTML;
  CurToken.Val     := TplHtmlBuf;
  CurToken.Line    := LexLineNo;
  CurToken.Col     := LexColNo;
  CurToken.IntVal  := 0;
  CurToken.RealVal := 0.0;
  Inc(TplHtmlCount);
  PrintToken(CurToken);
  TplHtmlBuf := '';
End;

{ ---- TplEmitPSPOpen : emettre un token PSP open ------------- }
Procedure TplEmitPSPOpen(Kind : TTokenKind);
Begin
  CurToken.Kind := Kind;
  CurToken.Line := LexLineNo;
  CurToken.Col  := LexColNo;
  CurToken.IntVal  := 0;
  CurToken.RealVal := 0.0;
  Case Kind Of
    TK_PSP_OPEN:      CurToken.Val := '<%';
    TK_PSP_EXPR_OPEN: CurToken.Val := '<%=';
    TK_PSP_DIRECTIVE:  CurToken.Val := '<%@';
  Else
    CurToken.Val := '';
  End;
  TplMode := TPL_CODE;
  PrintToken(CurToken);
End;

{ ---- TplNextToken : token suivant en mode template --------- }
{ Alterne entre mode HTML (accumulation texte brut) et mode    }
{ CODE (lexeur Pascal via LexNextToken).                       }
Procedure TplNextToken;
Var
  Ch    : Char;
  Kind  : TTokenKind;
Begin
  { 1) Si un tag PSP est en attente (apres emission de TK_HTML) }
  If TplPending <> TK_EOF Then
  Begin
    Kind := TplPending;
    TplPending := TK_EOF;
    TplEmitPSPOpen(Kind);
    Exit;
  End;

  { 2) Mode HTML : scanner caractere par caractere }
  If TplMode = TPL_HTML Then
  Begin
    TplHtmlBuf := '';

    While Not LexEOF Do
    Begin
      { Fin de ligne : ajouter saut de ligne au buffer }
      If LexColNo > Length(LexLine) Then
      Begin
        { Vider le buffer si presque plein (reserve pour CR+LF) }
        If Length(TplHtmlBuf) >= MAX_STR - 1 Then
        Begin
          TplEmitHtml;
          Exit;
        End;
        TplHtmlBuf := TplHtmlBuf + #13#10;
        LexNextLine;
        Continue;
      End;

      Ch := LexLine[LexColNo];

      { Detection de la balise ouvrante <pourcent }
      If (Ch = '<') And (LexColNo < Length(LexLine)) And
         (LexLine[LexColNo + 1] = '%') Then
      Begin
        Inc(LexColNo, 2);

        { Determiner le type : <%=  <%@  ou  <% simple }
        If (LexColNo <= Length(LexLine)) And
           (LexLine[LexColNo] = '=') Then
        Begin
          Kind := TK_PSP_EXPR_OPEN;
          Inc(LexColNo);
        End
        Else If (LexColNo <= Length(LexLine)) And
                (LexLine[LexColNo] = '@') Then
        Begin
          Kind := TK_PSP_DIRECTIVE;
          Inc(LexColNo);
        End
        Else
          Kind := TK_PSP_OPEN;

        { Si du HTML a emettre d abord, mettre le tag en attente }
        If Length(TplHtmlBuf) > 0 Then
        Begin
          TplPending := Kind;
          TplEmitHtml;
          Exit;
        End
        Else
        Begin
          { Pas de HTML, emettre directement le tag PSP }
          TplEmitPSPOpen(Kind);
          Exit;
        End;
      End
      Else
      Begin
        { Caractere HTML normal }
        If Length(TplHtmlBuf) >= MAX_STR Then
        Begin
          { Buffer plein : emettre le fragment }
          TplEmitHtml;
          Exit;
        End;
        TplHtmlBuf := TplHtmlBuf + Ch;
        Inc(LexColNo);
      End;
    End;

    { EOF atteint en mode HTML }
    If Length(TplHtmlBuf) > 0 Then
    Begin
      TplEmitHtml;
      Exit;
    End;

    { Plus de HTML, emettre TK_EOF }
    CurToken.Kind    := TK_EOF;
    CurToken.Val     := '';
    CurToken.Line    := LexLineNo;
    CurToken.Col     := LexColNo;
    CurToken.IntVal  := 0;
    CurToken.RealVal := 0.0;
    PrintToken(CurToken);
  End

  { 3) Mode CODE : deleguer au lexeur Pascal }
  Else
  Begin
    LexNextToken;

    { Si le lexeur retourne pourcent>, repasser en mode HTML }
    If CurToken.Kind = TK_PSP_CLOSE Then
      TplMode := TPL_HTML;
  End;
End;

{ ============================================================
  TODO 03 - LITTERAUX ET CONSTANTES [IMPLEMENTE]
  ============================================================ }

{ ---- LabelGen : generateur de labels uniques ---------------- }
Function LabelGen : TString;
Begin
  Inc(LabelGenSeq);
  LabelGen := PSP_LBL_PFX + IntToStr(LabelGenSeq);
End;

{ ---- EmitRaw : ecrire une ligne brute dans le fichier ASM --- }
Procedure EmitRaw(Const S : String);
Begin
  WriteLn(OutF, S);
End;

{ ---- DataAdd : ajouter une entree dans DataTab -------------- }
Function DataAdd(Const Lbl : TString; Kind : TDataKind;
                 AIntVal : LongInt; Const AStrVal : TString) : Integer;
Begin
  If DataCount >= MAX_DATA Then
    FatalError('DataTab pleine (MAX_DATA atteint)');
  DataTab[DataCount].LblName   := Lbl;
  DataTab[DataCount].Kind      := Kind;
  DataTab[DataCount].IntVal    := AIntVal;
  DataTab[DataCount].StrVal    := AStrVal;
  DataTab[DataCount].ElemCount := 0;
  DataTab[DataCount].ElemSize  := 0;
  DataTab[DataCount].RecSize   := 0;
  DataAdd := DataCount;
  Inc(DataCount);
End;

{ ---- DataAddStr : creer un label et stocker une chaine ------ }
{ Retourne le label genere (_PSPK_N).                           }
Function DataAddStr(Const S : TString) : TString;
Var
  Lbl : TString;
Begin
  Inc(LabelGenSeq);
  Lbl := PSP_STR_PFX + IntToStr(LabelGenSeq);
  DataAdd(Lbl, DK_STR, 0, S);
  DataAddStr := Lbl;
End;

{ ---- DataAddDWord : ajouter un double-mot 32 bits dans DataTab }
Function DataAddDWord(Const Lbl : TString; AIntVal : LongInt) : Integer;
Begin
  DataAddDWord := DataAdd(Lbl, DK_DWORD, AIntVal, '');
End;

{ ---- DataAddByte : ajouter un octet dans DataTab ------------ }
Function DataAddByte(Const Lbl : TString; AIntVal : LongInt) : Integer;
Begin
  DataAddByte := DataAdd(Lbl, DK_BYTE, AIntVal, '');
End;

{ ---- DataAddArray : ajouter un tableau dans DataTab --------- }
{ ECount = nombre d elements, ESz = taille d un element en octets }
Function DataAddArray(Const Lbl : TString;
                ECount, ESz : Integer) : Integer;
Var
  Idx : Integer;
Begin
  Idx := DataAdd(Lbl, DK_ARRAY, 0, '');
  DataTab[Idx].ElemCount := ECount;
  DataTab[Idx].ElemSize  := ESz;
  DataAddArray := Idx;
End;

{ ---- DataAddRec : ajouter un record dans DataTab ------------ }
{ RSz = taille totale du record en octets                         }
Function DataAddRec(Const Lbl : TString;
                RSz : Integer) : Integer;
Var
  Idx : Integer;
Begin
  Idx := DataAdd(Lbl, DK_REC, 0, '');
  DataTab[Idx].RecSize := RSz;
  DataAddRec := Idx;
End;

{ ---- EmitDataSeg : emettre le segment .DATA complet --------- }
{ Genere _DATA SEGMENT, les buffers internes, les entrees         }
{ dynamiques de DataTab, puis _DATA ENDS.                         }
{ Win32 : utilise DD (32 bits) pour DK_DWORD au lieu de DW.      }
Procedure EmitDataSeg;
Var
  I, J : Integer;
  S    : TString;
  Sz   : Integer;
Begin
  EmitRaw('_DATA   SEGMENT DWORD PUBLIC ''DATA''');

  { --- Buffers internes --- }
  EmitComment('--- Buffers internes ---');
  EmitRaw(PSP_RT_PFX + 'CRLF    DB  13,10,0');
  EmitRaw(PSP_RT_PFX + 'STRBUF  DB  512 DUP(0)');
  EmitRaw(PSP_RT_PFX + 'CHRBUF  DB  2 DUP(0)');
  EmitRaw(PSP_RT_PFX + 'NUMBUF  DB  12 DUP(0)');
  EmitRaw(PSP_RT_PFX + 'TRUE_S  DB  ''TRUE'',0');
  EmitRaw(PSP_RT_PFX + 'FALSE_S DB  ''FALSE'',0');
  EmitRaw(PSP_RT_PFX + 'HEAP    DB  4096 DUP(0)');
  EmitRaw(PSP_RT_PFX + 'HEAPTOP DD  OFFSET ' + PSP_RT_PFX + 'HEAP');
  EmitRaw(PSP_RT_PFX + 'SEED    DD  1');
  { Variables exception handler et messages panic }
  EmitRaw(PSP_EX_PFX + 'HANDLER DD  0');
  EmitRaw(PSP_EX_PFX + 'SAVESP  DD  0');
  EmitRaw(PSP_EX_PFX + 'SAVEBP  DD  0');
  EmitRaw(PSP_RT_PFX + 'DIV0MSG DB  ''Runtime error: Division by zero'',0');
  EmitRaw(PSP_RT_PFX + 'PANICMSG DB 0');
  { Handle stdout Win32 }
  EmitRaw(PSP_RT_PFX + 'HSTDOUT DD  0');
  EmitRaw(PSP_RT_PFX + 'WRITTEN DD  0');
  EmitBlankLine;

  { --- Entrees dynamiques de DataTab --- }
  If DataCount > 0 Then
    EmitComment('--- Donnees du programme ---');
  For I := 0 To DataCount - 1 Do
  Begin
    Case DataTab[I].Kind Of
      DK_DWORD :
        If DataTab[I].StrVal <> '' Then
          EmitRaw(DataTab[I].LblName + '  DD  OFFSET ' + DataTab[I].StrVal)
        Else
          EmitRaw(DataTab[I].LblName + '  DD  ' +
                  IntToStr(DataTab[I].IntVal));
      DK_BYTE :
        EmitRaw(DataTab[I].LblName + '  DB  ' +
                IntToStr(DataTab[I].IntVal));
      DK_STR :
        Begin
          { Doubler les apostrophes pour syntaxe MASM }
          S := '';
          For J := 1 To Length(DataTab[I].StrVal) Do
          Begin
            If DataTab[I].StrVal[J] = '''' Then
              S := S + ''''''
            Else
              S := S + DataTab[I].StrVal[J];
          End;
          EmitRaw(DataTab[I].LblName + '  DB  ''' + S + ''',0');
        End;
      DK_ARRAY :
        Begin
          { Tableau : DD/DB elem_count DUP(0) selon taille element }
          Sz := DataTab[I].ElemSize;
          If Sz <= 1 Then
            EmitRaw(DataTab[I].LblName + '  DB  ' +
                    IntToStr(DataTab[I].ElemCount) + ' DUP(0)')
          Else If Sz = 4 Then
            EmitRaw(DataTab[I].LblName + '  DD  ' +
                    IntToStr(DataTab[I].ElemCount) + ' DUP(0)')
          Else
            EmitRaw(DataTab[I].LblName + '  DB  ' +
                    IntToStr(DataTab[I].ElemCount * Sz) + ' DUP(0)');
        End;
      DK_REC :
        Begin
          { Record : DB rec_size DUP(0) }
          EmitRaw(DataTab[I].LblName + '  DB  ' +
                  IntToStr(DataTab[I].RecSize) + ' DUP(0)');
        End;
    End;
  End;

  EmitRaw('_DATA   ENDS');
End;

{ ---- LitEval : evaluer un token litteral en TExprVal -------- }
{ Gere : TK_INTEGER, TK_REAL (tronque+warn), TK_STRING,         }
{        TK_CHAR, TK_KEYWORD (true/false/nil).                  }
Procedure LitEval(Const T : TToken; Var Res : TExprVal);
Var
  Lw : TString;
Begin
  Res.Kind    := EK_NONE;
  Res.ImmVal  := 0;
  Res.TypeIdx := TY_UNKNOWN;
  Res.Offset  := 0;
  Res.SymIdx  := -1;

  Case T.Kind Of
    { --- Entiers (decimaux et hexadecimaux) --- }
    TK_INTEGER :
    Begin
      Res.Kind    := EK_IMM;
      Res.ImmVal  := T.IntVal;
      Res.TypeIdx := TY_IDX_INTEGER;
    End;

    { --- Reels : tronquer en entier + avertissement --- }
    TK_REAL :
    Begin
      WarnMsg('reel ' + T.Val + ' tronque en entier');
      Res.Kind    := EK_IMM;
      Res.ImmVal  := Trunc(T.RealVal);
      Res.TypeIdx := TY_IDX_INTEGER;
    End;

    { --- Chaines : stocker en DATA, retourner index DataTab --- }
    TK_STRING :
    Begin
      DataAddStr(T.Val);
      Res.Kind    := EK_AX;
      Res.ImmVal  := 0;
      Res.TypeIdx := TY_IDX_STRING;
      Res.SymIdx  := DataCount - 1;  { index de l entree dans DataTab }
    End;

    { --- Caracteres : valeur ordinale dans ImmVal --- }
    TK_CHAR :
    Begin
      If Length(T.Val) = 1 Then
      Begin
        Res.Kind    := EK_IMM;
        Res.ImmVal  := Ord(T.Val[1]);
        Res.TypeIdx := TY_IDX_CHAR;
      End
      Else
      Begin
        { Multi-caractere (#13#10 etc.) : traiter comme chaine }
        DataAddStr(T.Val);
        Res.Kind    := EK_AX;
        Res.ImmVal  := 0;
        Res.TypeIdx := TY_IDX_STRING;
        Res.SymIdx  := DataCount - 1;
      End;
    End;

    { --- Mots-cles speciaux : true, false, nil --- }
    TK_KEYWORD :
    Begin
      Lw := T.Val;
      If Lw = 'true' Then
      Begin
        Res.Kind    := EK_IMM;
        Res.ImmVal  := 1;
        Res.TypeIdx := TY_IDX_BOOLEAN;
      End
      Else If Lw = 'false' Then
      Begin
        Res.Kind    := EK_IMM;
        Res.ImmVal  := 0;
        Res.TypeIdx := TY_IDX_BOOLEAN;
      End
      Else If Lw = 'nil' Then
      Begin
        Res.Kind    := EK_IMM;
        Res.ImmVal  := 0;
        Res.TypeIdx := TY_IDX_NIL;
      End;
    End;
  Else
    { Token non reconnu comme litteral }
    Res.Kind := EK_NONE;
  End;
End;

{ ---- ParseConstDecl : analyser un bloc const ---------------- }
{ Syntaxe : const Ident = Expr;                                 }
{           const Ident : Type = Expr;                          }
{ Apres le mot-cle 'const', peut contenir plusieurs constantes. }
Procedure ParseConstDecl;
Var
  CName    : TString;
  CType    : TString;
  IsTyped  : Boolean;
  Ev       : TExprVal;
  Idx      : Integer;
  DIdx     : Integer;
  ResTIdx  : Integer;
Begin
  { Le mot-cle 'const' a deja ete consomme par l appelant }
  { Boucle : tant qu on voit un identificateur, on parse une constante }
  While (CurToken.Kind = TK_IDENT) Or
        ((CurToken.Kind = TK_KEYWORD) And
         ((CurToken.Val = 'integer') Or (CurToken.Val = 'word') Or
          (CurToken.Val = 'byte') Or (CurToken.Val = 'char') Or
          (CurToken.Val = 'boolean') Or (CurToken.Val = 'string') Or
          (CurToken.Val = 'real'))) Do
  Begin
    { Nom de la constante }
    If CurToken.Kind <> TK_IDENT Then
      Break;
    CName := CurToken.Val;
    TplNextToken;

    { Constante typee ? const X : Integer = 42; }
    IsTyped := False;
    CType   := '';
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ':') Then
    Begin
      IsTyped := True;
      TplNextToken;
      If (CurToken.Kind = TK_KEYWORD) Or (CurToken.Kind = TK_IDENT) Then
      Begin
        CType := CurToken.Val;
        TplNextToken;
      End
      Else
        WarnMsg('type attendu apres '':'' dans la constante ' + CName);
    End;

    { Signe = }
    If (CurToken.Kind = TK_OP) And (CurToken.Val = '=') Then
      TplNextToken
    Else
    Begin
      WarnMsg('''='' attendu dans la declaration de constante ' + CName);
      Break;
    End;

    { Valeur : expression constante (pliage de constantes) }
    ParseExpr(Ev);

    { Enregistrer la constante dans la table des symboles }
    If IsTyped Then
    Begin
      { Resoudre le nom de type }
      ResTIdx := TypeResolve(CType);
      If ResTIdx = TY_UNKNOWN Then
        WarnMsg('type inconnu: ' + CType);
      { Verifier compatibilite type declare vs valeur }
      If (ResTIdx <> TY_UNKNOWN) And (Ev.TypeIdx <> TY_UNKNOWN) Then
      Begin
        If Not TypeCompatible(ResTIdx, Ev.TypeIdx) Then
          WarnMsg('type incompatible pour la constante ' + CName);
      End;
      { Constante typee -> entree DATA + symbole SC_TYPED_CONST }
      If Ev.TypeIdx = TY_IDX_STRING Then
      Begin
        If Opts.DebugMode Then
          WriteLn('  CONST_TYPED: ', CName, ' : ', CType,
                  ' = ''', DataTab[Ev.SymIdx].StrVal, '''');
        DIdx := DataAdd(PSP_VAR_PFX + CName, DK_DWORD, 0,
                        DataTab[Ev.SymIdx].LblName);
      End
      Else
      Begin
        If Opts.DebugMode Then
          WriteLn('  CONST_TYPED: ', CName, ' : ', CType,
                  ' = ', Ev.ImmVal);
        DIdx := DataAddDWord(PSP_VAR_PFX + CName, Ev.ImmVal);
      End;
      Idx := SymAdd(CName, SC_TYPED_CONST, Ev.TypeIdx);
      If Idx >= 0 Then
      Begin
        SymTab[Idx].ImmVal  := Ev.ImmVal;
        SymTab[Idx].DataIdx := DIdx;
      End;
    End
    Else
    Begin
      { Constante non-typee -> substitution : symbole SC_CONST }
      { Valeur immediate stockee dans ImmVal de TSymRec         }
      If Ev.TypeIdx = TY_IDX_STRING Then
      Begin
        If Opts.DebugMode Then
          WriteLn('  CONST: ', CName,
                  ' = ''', DataTab[Ev.SymIdx].StrVal, '''');
        DIdx := DataAdd(PSP_VAR_PFX + CName, DK_DWORD, 0,
                        DataTab[Ev.SymIdx].LblName);
        Idx := SymAdd(CName, SC_CONST, Ev.TypeIdx);
        If Idx >= 0 Then
        Begin
          SymTab[Idx].ImmVal  := 0;
          SymTab[Idx].DataIdx := DIdx;
        End;
      End
      Else
      Begin
        If Opts.DebugMode Then
          WriteLn('  CONST: ', CName, ' = ', Ev.ImmVal);
        Idx := SymAdd(CName, SC_CONST, Ev.TypeIdx);
        If Idx >= 0 Then
        Begin
          SymTab[Idx].ImmVal  := Ev.ImmVal;
          SymTab[Idx].DataIdx := -1;
        End;
      End;
    End;

    { Point-virgule }
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
      TplNextToken;
  End;
End;

{ ============================================================
  TODO 05 - TABLE DES SYMBOLES [IMPLEMENTE]
  ============================================================ }

{ ---- SymMangle : generer le nom ASM mangled ------------------- }
{ Le prefixe depend de la categorie du symbole.                   }
Function SymMangle(Const Name : TString; Cat : TSymCat) : TString;
Var
  Pfx : TString;
Begin
  Case Cat Of
    SC_VAR        : Pfx := PSP_VAR_PFX;
    SC_CONST      : Pfx := PSP_VAR_PFX;
    SC_TYPED_CONST: Pfx := PSP_VAR_PFX;
    SC_PARAM      : Pfx := PSP_VAR_PFX;
    SC_VARPARAM   : Pfx := PSP_VAR_PFX;
    SC_FUNC       : Pfx := PSP_FN_PFX;
    SC_PROC       : Pfx := PSP_FN_PFX;
    SC_TYPE       : Pfx := '';
    SC_FIELD      : Pfx := PSP_REC_PFX;
    SC_ENUM_VAL   : Pfx := PSP_ENUM_PFX;
    SC_LABEL      : Pfx := PSP_LBL_PFX;
  Else
    Pfx := PSP_VAR_PFX;
  End;
  SymMangle := Pfx + StrUpperCase(Name);
End;

{ ---- SymAdd : ajouter un symbole dans la table --------------- }
{ Retourne l indice du symbole ajoute, ou -1 si table pleine.    }
{ Verifie les doublons dans le scope courant.                     }
Function SymAdd(Const Name : TString; Cat : TSymCat;
               TIdx : Integer) : Integer;
Var
  Lw  : TString;
  Idx : Integer;
  Dup : Integer;
Begin
  If SymCount >= MAX_SYM Then
  Begin
    WarnMsg('table des symboles pleine (MAX_SYM=' + IntToStr(MAX_SYM) + ')');
    SymAdd := -1;
    Exit;
  End;

  Lw := StrLowerCase(Name);

  { Verifier doublon dans le scope courant }
  Dup := SymFindInScope(Lw, CurScopeLevel);
  If Dup >= 0 Then
  Begin
    { Si c est un forward, on autorise la redefinition }
    If SymTab[Dup].IsForward Then
    Begin
      SymTab[Dup].IsForward := False;
      SymTab[Dup].TypeIdx   := TIdx;
      SymAdd := Dup;
      Exit;
    End
    Else
    Begin
      WarnMsg('symbole deja declare dans ce scope: ' + Name);
      SymAdd := Dup;
      Exit;
    End;
  End;

  Idx := SymCount;
  Inc(SymCount);
  Inc(TotalSyms);

  SymTab[Idx].Name        := Lw;
  SymTab[Idx].MangledName := SymMangle(Lw, Cat);
  SymTab[Idx].Cat         := Cat;
  SymTab[Idx].TypeIdx     := TIdx;
  SymTab[Idx].Offset      := 0;
  SymTab[Idx].ScopeLevel  := CurScopeLevel;
  SymTab[Idx].ScopeId     := CurScopeId;
  SymTab[Idx].IsForward   := False;
  SymTab[Idx].IsLocal     := (CurScopeLevel > 0);
  SymTab[Idx].ImmVal      := 0;
  SymTab[Idx].DataIdx     := -1;
  SymTab[Idx].ParamCnt    := 0;
  SymTab[Idx].VarParamMask:= 0;

  If Opts.DebugMode Then
    WriteLn('  SYM_ADD[', Idx, ']: ', Lw,
            ' cat=', Ord(Cat),
            ' scope=', CurScopeLevel,
            ' -> ', SymTab[Idx].MangledName);

  SymAdd := Idx;
End;

{ ---- SymFind : rechercher un symbole (interne -> global) ----- }
{ Parcourt la table du plus recent au plus ancien, retourne le    }
{ premier symbole dont le ScopeLevel est inferieur ou egal au     }
{ scope courant. Retourne -1 si non trouve.                       }
Function SymFind(Const Name : TString) : Integer;
Var
  I  : Integer;
  Lw : TString;
Begin
  Lw := StrLowerCase(Name);
  For I := SymCount - 1 DownTo 0 Do
  Begin
    If (SymTab[I].Name = Lw) And
       (SymTab[I].ScopeLevel <= CurScopeLevel) Then
    Begin
      SymFind := I;
      Exit;
    End;
  End;
  SymFind := -1;
End;

{ ---- SymFindInScope : rechercher dans un scope precis -------- }
{ Retourne l indice du symbole ou -1 si non trouve.               }
Function SymFindInScope(Const Name : TString;
                        Level : Integer) : Integer;
Var
  I  : Integer;
  Lw : TString;
Begin
  Lw := StrLowerCase(Name);
  For I := SymCount - 1 DownTo 0 Do
  Begin
    If (SymTab[I].Name = Lw) And
       (SymTab[I].ScopeLevel = Level) And
       ((Level = 0) Or (SymTab[I].ScopeId = CurScopeId)) Then
    Begin
      SymFindInScope := I;
      Exit;
    End;
  End;
  SymFindInScope := -1;
End;

{ ---- SymEnterScope : entrer dans un nouveau scope ------------ }
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

{ ---- SymLeaveScope : quitter le scope courant ---------------- }
{ Les symboles du scope courant restent dans la table mais ne     }
{ seront plus trouves par SymFind car ScopeLevel > CurScopeLevel. }
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
  { Restaurer le ScopeId du scope parent }
  If CurScopeLevel = 0 Then
    CurScopeId := 0
  Else
    CurScopeId := CurScopeLevel;
End;

{ ---- SymInit : predeclarer les types et symboles builtin ----- }
{ Enregistre les types primitifs et les constantes/procedures     }
{ predefinies dans la table des symboles au scope global (0).     }
Procedure SymInit;
Var
  Idx : Integer;
Begin
  SymCount      := 0;
  CurScopeLevel := 0;
  CurScopeId    := 0;
  ScopeIdSeq    := 0;
  TotalSyms     := 0;

  { Types primitifs (32 bits) }
  Idx := SymAdd('integer', SC_TYPE, TY_IDX_INTEGER);
  If Idx >= 0 Then SymTab[Idx].MangledName := 'INTEGER';
  Idx := SymAdd('word', SC_TYPE, TY_IDX_WORD);
  If Idx >= 0 Then SymTab[Idx].MangledName := 'WORD';
  Idx := SymAdd('byte', SC_TYPE, TY_IDX_BYTE);
  If Idx >= 0 Then SymTab[Idx].MangledName := 'BYTE';
  Idx := SymAdd('char', SC_TYPE, TY_IDX_CHAR);
  If Idx >= 0 Then SymTab[Idx].MangledName := 'CHAR';
  Idx := SymAdd('boolean', SC_TYPE, TY_IDX_BOOLEAN);
  If Idx >= 0 Then SymTab[Idx].MangledName := 'BOOLEAN';
  Idx := SymAdd('string', SC_TYPE, TY_IDX_STRING);
  If Idx >= 0 Then SymTab[Idx].MangledName := 'STRING';
  Idx := SymAdd('real', SC_TYPE, TY_IDX_REAL);
  If Idx >= 0 Then SymTab[Idx].MangledName := 'REAL';
  Idx := SymAdd('pointer', SC_TYPE, TY_IDX_POINTER);
  If Idx >= 0 Then SymTab[Idx].MangledName := 'POINTER';
  Idx := SymAdd('text', SC_TYPE, TY_IDX_TEXT);
  If Idx >= 0 Then SymTab[Idx].MangledName := 'TEXT';

  { Constantes predefinies : true, false, nil, maxint }
  Idx := SymAdd('true', SC_CONST, TY_IDX_BOOLEAN);
  If Idx >= 0 Then
  Begin
    SymTab[Idx].ImmVal := 1;
    SymTab[Idx].MangledName := 'TRUE';
  End;
  Idx := SymAdd('false', SC_CONST, TY_IDX_BOOLEAN);
  If Idx >= 0 Then
  Begin
    SymTab[Idx].ImmVal := 0;
    SymTab[Idx].MangledName := 'FALSE';
  End;
  Idx := SymAdd('nil', SC_CONST, TY_IDX_NIL);
  If Idx >= 0 Then
  Begin
    SymTab[Idx].ImmVal := 0;
    SymTab[Idx].MangledName := 'NIL';
  End;
  Idx := SymAdd('maxint', SC_CONST, TY_IDX_INTEGER);
  If Idx >= 0 Then
  Begin
    SymTab[Idx].ImmVal := 2147483647;
    SymTab[Idx].MangledName := 'MAXINT';
  End;

  { Procedures/fonctions runtime predeclarees (Win32) }
  Idx := SymAdd('write', SC_PROC, TY_UNKNOWN);
  If Idx >= 0 Then SymTab[Idx].MangledName := PSP_RT_PFX + 'WRITE';
  Idx := SymAdd('writeln', SC_PROC, TY_UNKNOWN);
  If Idx >= 0 Then SymTab[Idx].MangledName := PSP_RT_PFX + 'WRITELN';
  Idx := SymAdd('read', SC_PROC, TY_UNKNOWN);
  If Idx >= 0 Then SymTab[Idx].MangledName := PSP_RT_PFX + 'READ';
  Idx := SymAdd('readln', SC_PROC, TY_UNKNOWN);
  If Idx >= 0 Then SymTab[Idx].MangledName := PSP_RT_PFX + 'READLN';
End;

{ ============================================================
  TODO 06 - SYSTEME DE TYPES (32 BITS) [IMPLEMENTE]
  ============================================================ }

{ ---- TypeInit : enregistrer les types primitifs 32 bits ------ }
Procedure TypeInit;

  Procedure AddPrim(Idx : Integer; K : TTypeKind; Sz : Integer);
  Begin
    TypeTab[Idx].Kind        := K;
    TypeTab[Idx].Size        := Sz;
    TypeTab[Idx].BaseTypeIdx := TY_UNKNOWN;
    TypeTab[Idx].Lo          := 0;
    TypeTab[Idx].Hi          := 0;
    TypeTab[Idx].FieldCount  := 0;
    TypeTab[Idx].EnumCount   := 0;
  End;

Begin
  TypeCount := TY_PRIM_COUNT;
  AddPrim(TY_IDX_INTEGER, TKP_INTEGER, 4);   { Integer : 4 octets (32 bits signe)    }
  AddPrim(TY_IDX_WORD,    TKP_WORD,    4);   { Word    : 4 octets (32 bits non signe) }
  AddPrim(TY_IDX_BYTE,    TKP_BYTE,    1);   { Byte    : 1 octet                      }
  AddPrim(TY_IDX_CHAR,    TKP_CHAR,    1);   { Char    : 1 octet                      }
  AddPrim(TY_IDX_BOOLEAN, TKP_BOOLEAN, 1);   { Boolean : 1 octet (etendu EAX)         }
  AddPrim(TY_IDX_STRING,  TKP_STRING,  4);   { String  : 4 (ptr ASCIIZ 32 bits)       }
  AddPrim(TY_IDX_REAL,    TKP_REAL,    4);   { Real    : 4 (tronque en entier 32 bits) }
  AddPrim(TY_IDX_POINTER, TKP_POINTER, 4);   { Pointer : 4 octets (32 bits)           }
  AddPrim(TY_IDX_NIL,     TKP_NIL,     4);   { nil     : 4 octets                     }
  AddPrim(TY_IDX_TEXT,    TKP_TEXT,    4);    { Text    : 4 (handle Win32)             }
End;

{ ---- TypeSizeof : retourner la taille d un type en octets ---- }
Function TypeSizeof(TIdx : Integer) : Integer;
Begin
  If (TIdx >= 0) And (TIdx < TypeCount) Then
    TypeSizeof := TypeTab[TIdx].Size
  Else
    TypeSizeof := 4;  { taille par defaut = DWORD 32 bits }
End;

{ ---- TypeIsOrdinal : le type est-il ordinal ? ---------------- }
Function TypeIsOrdinal(TIdx : Integer) : Boolean;
Begin
  If (TIdx < 0) Or (TIdx >= TypeCount) Then
  Begin
    TypeIsOrdinal := False;
    Exit;
  End;
  Case TypeTab[TIdx].Kind Of
    TKP_INTEGER, TKP_WORD, TKP_BYTE, TKP_CHAR,
    TKP_BOOLEAN, TKP_ENUM, TKP_SUBRANGE :
      TypeIsOrdinal := True;
  Else
    TypeIsOrdinal := False;
  End;
End;

{ ---- TypeIsNumeric : le type est-il numerique ? -------------- }
Function TypeIsNumeric(TIdx : Integer) : Boolean;
Begin
  If (TIdx < 0) Or (TIdx >= TypeCount) Then
  Begin
    TypeIsNumeric := False;
    Exit;
  End;
  Case TypeTab[TIdx].Kind Of
    TKP_INTEGER, TKP_WORD, TKP_BYTE, TKP_REAL :
      TypeIsNumeric := True;
  Else
    TypeIsNumeric := False;
  End;
End;

{ ---- TypeIsPointer : le type est-il un pointeur ? ------------ }
Function TypeIsPointer(TIdx : Integer) : Boolean;
Begin
  If (TIdx < 0) Or (TIdx >= TypeCount) Then
  Begin
    TypeIsPointer := False;
    Exit;
  End;
  Case TypeTab[TIdx].Kind Of
    TKP_POINTER, TKP_NIL, TKP_STRING :
      TypeIsPointer := True;
  Else
    TypeIsPointer := False;
  End;
End;

{ ---- TypeCompatible : deux types sont-ils compatibles ? ------ }
Function TypeCompatible(T1, T2 : Integer) : Boolean;
Var
  K1, K2 : TTypeKind;
Begin
  { Types identiques : toujours compatible }
  If T1 = T2 Then
  Begin
    TypeCompatible := True;
    Exit;
  End;

  { Si l un des deux est inconnu, accepter }
  If (T1 = TY_UNKNOWN) Or (T2 = TY_UNKNOWN) Then
  Begin
    TypeCompatible := True;
    Exit;
  End;

  { Verifier les bornes }
  If (T1 < 0) Or (T1 >= TypeCount) Or
     (T2 < 0) Or (T2 >= TypeCount) Then
  Begin
    TypeCompatible := False;
    Exit;
  End;

  K1 := TypeTab[T1].Kind;
  K2 := TypeTab[T2].Kind;

  { nil -> tout type pointeur ou string }
  If K2 = TKP_NIL Then
  Begin
    TypeCompatible := (K1 = TKP_POINTER) Or (K1 = TKP_STRING) Or
                      (K1 = TKP_NIL);
    Exit;
  End;

  { Integer <-> Word (implicite) }
  If ((K1 = TKP_INTEGER) Or (K1 = TKP_WORD)) And
     ((K2 = TKP_INTEGER) Or (K2 = TKP_WORD)) Then
  Begin
    TypeCompatible := True;
    Exit;
  End;

  { Byte -> Integer ou Word (promotion implicite) }
  If (K2 = TKP_BYTE) And
     ((K1 = TKP_INTEGER) Or (K1 = TKP_WORD) Or (K1 = TKP_BYTE)) Then
  Begin
    TypeCompatible := True;
    Exit;
  End;

  { Integer/Word -> Byte (retrecissement implicite) }
  If (K1 = TKP_BYTE) And
     ((K2 = TKP_INTEGER) Or (K2 = TKP_WORD)) Then
  Begin
    TypeCompatible := True;
    Exit;
  End;

  { Char <-> Integer (Ord/Chr) }
  If ((K1 = TKP_CHAR) And (K2 = TKP_INTEGER)) Or
     ((K1 = TKP_INTEGER) And (K2 = TKP_CHAR)) Then
  Begin
    TypeCompatible := True;
    Exit;
  End;

  { Char <-> Byte }
  If ((K1 = TKP_CHAR) And (K2 = TKP_BYTE)) Or
     ((K1 = TKP_BYTE) And (K2 = TKP_CHAR)) Then
  Begin
    TypeCompatible := True;
    Exit;
  End;

  { Char <-> String (conversion implicite) }
  If ((K1 = TKP_CHAR) And (K2 = TKP_STRING)) Or
     ((K1 = TKP_STRING) And (K2 = TKP_CHAR)) Then
  Begin
    TypeCompatible := True;
    Exit;
  End;

  { Boolean -> Integer (0|1) }
  If (K2 = TKP_BOOLEAN) And
     ((K1 = TKP_INTEGER) Or (K1 = TKP_WORD) Or (K1 = TKP_BYTE)) Then
  Begin
    TypeCompatible := True;
    Exit;
  End;

  { Integer -> Boolean (non-zero = true) }
  If (K1 = TKP_BOOLEAN) And
     ((K2 = TKP_INTEGER) Or (K2 = TKP_WORD) Or (K2 = TKP_BYTE)) Then
  Begin
    TypeCompatible := True;
    Exit;
  End;

  { Enum -> Integer (Ord) }
  If (K2 = TKP_ENUM) And
     ((K1 = TKP_INTEGER) Or (K1 = TKP_WORD)) Then
  Begin
    TypeCompatible := True;
    Exit;
  End;

  { Subrange -> son type de base }
  If (K2 = TKP_SUBRANGE) And
     (TypeTab[T2].BaseTypeIdx = T1) Then
  Begin
    TypeCompatible := True;
    Exit;
  End;
  If (K1 = TKP_SUBRANGE) And
     (TypeTab[T1].BaseTypeIdx = T2) Then
  Begin
    TypeCompatible := True;
    Exit;
  End;

  { Real <-> Integer (tronquage implicite) }
  If ((K1 = TKP_REAL) And ((K2 = TKP_INTEGER) Or (K2 = TKP_WORD))) Or
     (((K1 = TKP_INTEGER) Or (K1 = TKP_WORD)) And (K2 = TKP_REAL)) Then
  Begin
    TypeCompatible := True;
    Exit;
  End;

  { Pointer <-> tout type pointeur }
  If ((K1 = TKP_POINTER) And (K2 = TKP_POINTER)) Then
  Begin
    TypeCompatible := True;
    Exit;
  End;

  TypeCompatible := False;
End;

{ ---- TypeCoerce : emettre le code de conversion 32 bits ------ }
Function TypeCoerce(SrcType, DstType : Integer) : Integer;
Var
  Ks, Kd : TTypeKind;
Begin
  { Meme type : rien a faire }
  If SrcType = DstType Then
  Begin
    TypeCoerce := SrcType;
    Exit;
  End;

  { Inconnu : pas de conversion }
  If (SrcType = TY_UNKNOWN) Or (DstType = TY_UNKNOWN) Then
  Begin
    If DstType <> TY_UNKNOWN Then
      TypeCoerce := DstType
    Else
      TypeCoerce := SrcType;
    Exit;
  End;

  If (SrcType < 0) Or (SrcType >= TypeCount) Or
     (DstType < 0) Or (DstType >= TypeCount) Then
  Begin
    TypeCoerce := DstType;
    Exit;
  End;

  Ks := TypeTab[SrcType].Kind;
  Kd := TypeTab[DstType].Kind;

  { Byte -> Integer/Word : extension zero MOVZX EAX, AL }
  If (Ks = TKP_BYTE) And ((Kd = TKP_INTEGER) Or (Kd = TKP_WORD)) Then
  Begin
    EmitComment('coerce byte -> dword');
    EmitInstrAB('MOVZX', 'EAX', 'AL');
    TypeCoerce := DstType;
    Exit;
  End;

  { Char -> Integer : meme que Byte -> Integer (Ord) }
  If (Ks = TKP_CHAR) And ((Kd = TKP_INTEGER) Or (Kd = TKP_WORD)) Then
  Begin
    EmitComment('coerce char -> dword (Ord)');
    EmitInstrAB('MOVZX', 'EAX', 'AL');
    TypeCoerce := DstType;
    Exit;
  End;

  { Integer/Word -> Byte : troncature (prendre AL) }
  If ((Ks = TKP_INTEGER) Or (Ks = TKP_WORD)) And (Kd = TKP_BYTE) Then
  Begin
    EmitComment('coerce dword -> byte (troncature)');
    { EAX contient la valeur, AL est deja le byte bas }
    TypeCoerce := DstType;
    Exit;
  End;

  { Boolean -> Integer : extension zero MOVZX EAX, AL }
  If (Ks = TKP_BOOLEAN) And
     ((Kd = TKP_INTEGER) Or (Kd = TKP_WORD)) Then
  Begin
    EmitComment('coerce boolean -> dword');
    EmitInstrAB('MOVZX', 'EAX', 'AL');
    TypeCoerce := DstType;
    Exit;
  End;

  { Integer -> Boolean : CMP EAX,0 / SETNE AL / MOVZX EAX, AL }
  If ((Ks = TKP_INTEGER) Or (Ks = TKP_WORD)) And
     (Kd = TKP_BOOLEAN) Then
  Begin
    EmitComment('coerce dword -> boolean');
    EmitInstrAB('CMP', 'EAX', '0');
    EmitInstrA('SETNE', 'AL');
    EmitInstrAB('MOVZX', 'EAX', 'AL');
    TypeCoerce := DstType;
    Exit;
  End;

  { Char -> String : sera gere par le runtime (Chr) }
  If (Ks = TKP_CHAR) And (Kd = TKP_STRING) Then
  Begin
    EmitComment('coerce char -> string (runtime)');
    TypeCoerce := DstType;
    Exit;
  End;

  { nil -> Pointer/String : valeur deja 0 }
  If (Ks = TKP_NIL) And ((Kd = TKP_POINTER) Or (Kd = TKP_STRING)) Then
  Begin
    TypeCoerce := DstType;
    Exit;
  End;

  { Real -> Integer : tronquage (deja fait par le front-end) }
  If (Ks = TKP_REAL) And ((Kd = TKP_INTEGER) Or (Kd = TKP_WORD)) Then
  Begin
    WarnMsg('reel tronque en entier');
    TypeCoerce := DstType;
    Exit;
  End;

  { Integer -> Real : on garde la valeur entiere }
  If ((Ks = TKP_INTEGER) Or (Ks = TKP_WORD)) And (Kd = TKP_REAL) Then
  Begin
    TypeCoerce := DstType;
    Exit;
  End;

  { Enum -> Integer (Ord) }
  If (Ks = TKP_ENUM) And ((Kd = TKP_INTEGER) Or (Kd = TKP_WORD)) Then
  Begin
    EmitComment('coerce enum -> dword (Ord)');
    TypeCoerce := DstType;
    Exit;
  End;

  { Integer <-> Word : meme representation 32 bits, pas de code }
  If ((Ks = TKP_INTEGER) And (Kd = TKP_WORD)) Or
     ((Ks = TKP_WORD) And (Kd = TKP_INTEGER)) Then
  Begin
    If Opts.Warnings Then
      WarnMsg('conversion implicite signe <-> non-signe');
    TypeCoerce := DstType;
    Exit;
  End;

  { Pas de conversion connue : avertissement }
  If Opts.Warnings Then
    WarnMsg('conversion de type implicite non supportee');
  TypeCoerce := DstType;
End;

{ ---- TypeResolve : resoudre un nom de type ------------------- }
Function TypeResolve(Const Name : TString) : Integer;
Var
  Idx : Integer;
Begin
  Idx := SymFind(Name);
  If (Idx >= 0) And (SymTab[Idx].Cat = SC_TYPE) Then
    TypeResolve := SymTab[Idx].TypeIdx
  Else
    TypeResolve := TY_UNKNOWN;
End;

{ ============================================================
  TODO 07 - EMETTEUR DE CODE ASM 80386 [IMPLEMENTE]
  ============================================================ }

{ ---- EmitComment : ecrire un commentaire ASM ----------------- }
Procedure EmitComment(Const S : TString);
Begin
  EmitRaw('; ' + S);
End;

{ ---- EmitLabel : ecrire un label avec deux-points ------------ }
Procedure EmitLabel(Const Lbl : TString);
Begin
  EmitRaw(Lbl + ':');
End;

{ ---- EmitInstr : instruction sans operande ------------------- }
Procedure EmitInstr(Const Mnem : TString);
Begin
  EmitRaw('        ' + Mnem);
End;

{ ---- EmitInstrA : instruction avec un operande --------------- }
Procedure EmitInstrA(Const Mnem, A1 : TString);
Begin
  EmitRaw('        ' + Mnem + '   ' + A1);
End;

{ ---- EmitInstrAB : instruction avec deux operandes ----------- }
Procedure EmitInstrAB(Const Mnem, A1, A2 : TString);
Begin
  EmitRaw('        ' + Mnem + '   ' + A1 + ', ' + A2);
End;

{ ---- EmitBlankLine : ligne vide ------------------------------ }
Procedure EmitBlankLine;
Begin
  WriteLn(OutF);
End;

{ ---- NewLabel : generer un label unique ---------------------- }
Function NewLabel : TString;
Begin
  NewLabel := LabelGen;
End;

{ ---- EmitHeader : en-tete ASM Win32 FLAT --------------------- }
Procedure EmitHeader;
Begin
  EmitComment('========================================');
  EmitComment('Genere par PSPCW32 v' + PSPCW32_VERSION +
              ' (' + PSPCW32_DATE + ')');
  EmitComment('Source : ' + Opts.SrcFile);
  EmitComment('Cible  : Win32 / 80386 / PE');
  EmitComment('========================================');
  EmitBlankLine;
  EmitRaw('.386');
  EmitRaw('.MODEL FLAT, STDCALL');
  EmitRaw('OPTION CASEMAP:NONE');
  EmitBlankLine;
  EmitComment('--- Declarations externes Win32 ---');
  EmitRaw('EXTRN   _ExitProcess@4       : PROC');
  EmitRaw('EXTRN   _GetStdHandle@4      : PROC');
  EmitRaw('EXTRN   _WriteFile@20        : PROC');
  EmitRaw('EXTRN   _ReadFile@20         : PROC');
  EmitRaw('EXTRN   _GetProcessHeap@0    : PROC');
  EmitRaw('EXTRN   _HeapAlloc@12        : PROC');
  EmitRaw('EXTRN   _HeapFree@12         : PROC');
  EmitBlankLine;
  EmitRaw('.STACK ' + IntToStr(STACK_SIZE));
  EmitBlankLine;
  EmitComment('--- Segment de code ---');
  EmitRaw('_TEXT   SEGMENT DWORD PUBLIC ''CODE''');
  EmitRaw('        ASSUME CS:_TEXT');
  EmitBlankLine;
  EmitComment('--- Point d entree principal ---');
  EmitLabel(PSP_FN_PFX + 'main');
  EmitComment('Obtenir le handle stdout');
  EmitInstrA('PUSH', '-11');
  EmitInstrA('CALL', '_GetStdHandle@4');
  EmitInstrAB('MOV', 'DWORD PTR [' + PSP_RT_PFX + 'HSTDOUT]', 'EAX');
  EmitBlankLine;
  EmitInstrA('JMP', PSP_LBL_PFX + 'MAINBODY');
  EmitBlankLine;
End;

{ ---- EmitFooter : pied de page ASM + runtime 32 bits --------- }
Procedure EmitFooter;
Begin
  EmitBlankLine;
  { Emettre le label MAINBODY si pas deja fait }
  If Not MainBodyEmitted Then
  Begin
    EmitLabel(PSP_LBL_PFX + 'MAINBODY');
    MainBodyEmitted := True;
  End;
  EmitBlankLine;
  EmitComment('--- Sortie programme ---');
  EmitInstrA('PUSH', '0');
  EmitInstrA('CALL', '_ExitProcess@4');
  EmitBlankLine;

  { -- Routines runtime 32 bits -- }
  If Not RuntimeEmitted Then
  Begin
    RuntimeEmitted := True;
    EmitComment('========================================');
    EmitComment('  ROUTINES RUNTIME 32 BITS');
    EmitComment('========================================');
    EmitBlankLine;

    { _PSPRT_PRINTSTR : afficher chaine ASCIIZ pointee par ESI }
    EmitLabel(PSP_RT_PFX + 'PRINTSTR');
    EmitInstrA('PUSH', 'ESI');
    EmitInstrAB('MOV', 'EDI', 'ESI');
    EmitComment('calculer la longueur');
    EmitInstrAB('XOR', 'ECX', 'ECX');
    EmitLabel(PSP_RT_PFX + 'PRINTSTR_L');
    EmitInstrAB('CMP', 'BYTE PTR [EDI]', '0');
    EmitInstrA('JE', PSP_RT_PFX + 'PRINTSTR_W');
    EmitInstrA('INC', 'EDI');
    EmitInstrA('INC', 'ECX');
    EmitInstrA('JMP', PSP_RT_PFX + 'PRINTSTR_L');
    EmitLabel(PSP_RT_PFX + 'PRINTSTR_W');
    EmitComment('WriteFile(hStdout, pStr, len, pWritten, 0)');
    EmitInstrA('PUSH', '0');
    EmitInstrA('PUSH', 'OFFSET ' + PSP_RT_PFX + 'WRITTEN');
    EmitInstrA('PUSH', 'ECX');
    EmitInstrA('PUSH', 'ESI');
    EmitInstrA('PUSH', 'DWORD PTR [' + PSP_RT_PFX + 'HSTDOUT]');
    EmitInstrA('CALL', '_WriteFile@20');
    EmitInstrA('POP', 'ESI');
    EmitInstr('RET');
    EmitBlankLine;

    { _PSPRT_NUMTOSTR : convertir EAX signe -> ASCIIZ dans NUMBUF }
    EmitLabel(PSP_RT_PFX + 'NUMTOSTR');
    EmitInstrA('PUSH', 'EBX');
    EmitInstrA('PUSH', 'ECX');
    EmitInstrA('PUSH', 'EDX');
    EmitInstrA('PUSH', 'EDI');
    EmitInstrAB('LEA', 'EDI', PSP_RT_PFX + 'NUMBUF + 15');
    EmitInstrAB('MOV', 'BYTE PTR [EDI]', '0');
    EmitInstrAB('MOV', 'ECX', '0');
    EmitInstrAB('MOV', 'EBX', '10');
    EmitInstrAB('CMP', 'EAX', '0');
    EmitInstrA('JGE', PSP_RT_PFX + 'NTS_POS');
    EmitInstrA('NEG', 'EAX');
    EmitInstrAB('MOV', 'ECX', '1');
    EmitLabel(PSP_RT_PFX + 'NTS_POS');
    EmitInstrAB('CMP', 'EAX', '0');
    EmitInstrA('JNE', PSP_RT_PFX + 'NTS_LOOP');
    EmitInstrA('DEC', 'EDI');
    EmitInstrAB('MOV', 'BYTE PTR [EDI]', '''0''');
    EmitInstrA('JMP', PSP_RT_PFX + 'NTS_SIGN');
    EmitLabel(PSP_RT_PFX + 'NTS_LOOP');
    EmitInstrAB('CMP', 'EAX', '0');
    EmitInstrA('JE', PSP_RT_PFX + 'NTS_SIGN');
    EmitInstrAB('XOR', 'EDX', 'EDX');
    EmitInstrA('DIV', 'EBX');
    EmitInstrAB('ADD', 'DL', '''0''');
    EmitInstrA('DEC', 'EDI');
    EmitInstrAB('MOV', 'BYTE PTR [EDI]', 'DL');
    EmitInstrA('JMP', PSP_RT_PFX + 'NTS_LOOP');
    EmitLabel(PSP_RT_PFX + 'NTS_SIGN');
    EmitInstrAB('CMP', 'ECX', '1');
    EmitInstrA('JNE', PSP_RT_PFX + 'NTS_DONE');
    EmitInstrA('DEC', 'EDI');
    EmitInstrAB('MOV', 'BYTE PTR [EDI]', '''-''');
    EmitLabel(PSP_RT_PFX + 'NTS_DONE');
    EmitInstrAB('MOV', 'EAX', 'EDI');
    EmitInstrA('POP', 'EDI');
    EmitInstrA('POP', 'EDX');
    EmitInstrA('POP', 'ECX');
    EmitInstrA('POP', 'EBX');
    EmitInstr('RET');
    EmitBlankLine;

    { _PSPRT_STRLEN : longueur chaine ASCIIZ ESI -> EAX }
    EmitLabel(PSP_RT_PFX + 'STRLEN');
    EmitInstrA('PUSH', 'EDI');
    EmitInstrAB('MOV', 'EDI', 'ESI');
    EmitInstrAB('XOR', 'EAX', 'EAX');
    EmitLabel(PSP_RT_PFX + 'STRLEN_L');
    EmitInstrAB('CMP', 'BYTE PTR [EDI]', '0');
    EmitInstrA('JE', PSP_RT_PFX + 'STRLEN_D');
    EmitInstrA('INC', 'EDI');
    EmitInstrA('INC', 'EAX');
    EmitInstrA('JMP', PSP_RT_PFX + 'STRLEN_L');
    EmitLabel(PSP_RT_PFX + 'STRLEN_D');
    EmitInstrA('POP', 'EDI');
    EmitInstr('RET');
    EmitBlankLine;

    { _PSPRT_CONCAT : ESI + EDI -> STRBUF, EAX = OFFSET STRBUF }
    EmitLabel(PSP_RT_PFX + 'CONCAT');
    EmitInstrA('PUSH', 'EBX');
    EmitInstrAB('LEA', 'EBX', PSP_RT_PFX + 'STRBUF');
    EmitLabel(PSP_RT_PFX + 'CONC_L1');
    EmitInstrAB('MOV', 'AL', 'BYTE PTR [ESI]');
    EmitInstrAB('MOV', 'BYTE PTR [EBX]', 'AL');
    EmitInstrAB('CMP', 'AL', '0');
    EmitInstrA('JE', PSP_RT_PFX + 'CONC_L2');
    EmitInstrA('INC', 'ESI');
    EmitInstrA('INC', 'EBX');
    EmitInstrA('JMP', PSP_RT_PFX + 'CONC_L1');
    EmitLabel(PSP_RT_PFX + 'CONC_L2');
    EmitInstrAB('MOV', 'AL', 'BYTE PTR [EDI]');
    EmitInstrAB('MOV', 'BYTE PTR [EBX]', 'AL');
    EmitInstrAB('CMP', 'AL', '0');
    EmitInstrA('JE', PSP_RT_PFX + 'CONC_DN');
    EmitInstrA('INC', 'EDI');
    EmitInstrA('INC', 'EBX');
    EmitInstrA('JMP', PSP_RT_PFX + 'CONC_L2');
    EmitLabel(PSP_RT_PFX + 'CONC_DN');
    EmitInstrAB('LEA', 'EAX', PSP_RT_PFX + 'STRBUF');
    EmitInstrA('POP', 'EBX');
    EmitInstr('RET');
    EmitBlankLine;

    { _PSPRT_STRCMP : ESI vs EDI -> EAX (-1/0/+1) }
    EmitLabel(PSP_RT_PFX + 'STRCMP');
    EmitInstrA('PUSH', 'EBX');
    EmitLabel(PSP_RT_PFX + 'SCMP_L');
    EmitInstrAB('MOV', 'AL', 'BYTE PTR [ESI]');
    EmitInstrAB('MOV', 'BL', 'BYTE PTR [EDI]');
    EmitInstrAB('CMP', 'AL', 'BL');
    EmitInstrA('JB', PSP_RT_PFX + 'SCMP_LT');
    EmitInstrA('JA', PSP_RT_PFX + 'SCMP_GT');
    EmitInstrAB('CMP', 'AL', '0');
    EmitInstrA('JE', PSP_RT_PFX + 'SCMP_EQ');
    EmitInstrA('INC', 'ESI');
    EmitInstrA('INC', 'EDI');
    EmitInstrA('JMP', PSP_RT_PFX + 'SCMP_L');
    EmitLabel(PSP_RT_PFX + 'SCMP_EQ');
    EmitInstrAB('XOR', 'EAX', 'EAX');
    EmitInstrA('JMP', PSP_RT_PFX + 'SCMP_DN');
    EmitLabel(PSP_RT_PFX + 'SCMP_LT');
    EmitInstrAB('MOV', 'EAX', '-1');
    EmitInstrA('JMP', PSP_RT_PFX + 'SCMP_DN');
    EmitLabel(PSP_RT_PFX + 'SCMP_GT');
    EmitInstrAB('MOV', 'EAX', '1');
    EmitLabel(PSP_RT_PFX + 'SCMP_DN');
    EmitInstrA('POP', 'EBX');
    EmitInstr('RET');
    EmitBlankLine;

    { _PSPRT_WRITECRLF : ecrire CR+LF }
    EmitLabel(PSP_RT_PFX + 'WRITECRLF');
    EmitInstrAB('LEA', 'ESI', PSP_RT_PFX + 'CRLF');
    EmitInstrA('CALL', PSP_RT_PFX + 'PRINTSTR');
    EmitInstr('RET');
    EmitBlankLine;

    { _PSPRT_CHR : AL -> chaine 1 car dans CHRBUF, EAX = ptr }
    EmitLabel(PSP_RT_PFX + 'CHR');
    EmitInstrAB('MOV', 'BYTE PTR [' + PSP_RT_PFX + 'CHRBUF]', 'AL');
    EmitInstrAB('MOV', 'BYTE PTR [' + PSP_RT_PFX + 'CHRBUF + 1]', '0');
    EmitInstrAB('LEA', 'EAX', PSP_RT_PFX + 'CHRBUF');
    EmitInstr('RET');
    EmitBlankLine;

    { _PSPRT_STRTONUM : ESI (ASCIIZ) -> EAX (entier signe) }
    EmitLabel(PSP_RT_PFX + 'STRTONUM');
    EmitInstrA('PUSH', 'EBX');
    EmitInstrA('PUSH', 'ECX');
    EmitInstrAB('XOR', 'EAX', 'EAX');
    EmitInstrAB('XOR', 'ECX', 'ECX');
    EmitInstrAB('CMP', 'BYTE PTR [ESI]', '''-''');
    EmitInstrA('JNE', PSP_RT_PFX + 'STN_LP');
    EmitInstrAB('MOV', 'ECX', '1');
    EmitInstrA('INC', 'ESI');
    EmitLabel(PSP_RT_PFX + 'STN_LP');
    EmitInstrAB('MOVZX', 'EBX', 'BYTE PTR [ESI]');
    EmitInstrAB('CMP', 'EBX', '''0''');
    EmitInstrA('JB', PSP_RT_PFX + 'STN_DN');
    EmitInstrAB('CMP', 'EBX', '''9''');
    EmitInstrA('JA', PSP_RT_PFX + 'STN_DN');
    EmitInstrAB('SUB', 'EBX', '''0''');
    EmitInstrAB('IMUL', 'EAX', '10');
    EmitInstrAB('ADD', 'EAX', 'EBX');
    EmitInstrA('INC', 'ESI');
    EmitInstrA('JMP', PSP_RT_PFX + 'STN_LP');
    EmitLabel(PSP_RT_PFX + 'STN_DN');
    EmitInstrAB('CMP', 'ECX', '1');
    EmitInstrA('JNE', PSP_RT_PFX + 'STN_OK');
    EmitInstrA('NEG', 'EAX');
    EmitLabel(PSP_RT_PFX + 'STN_OK');
    EmitInstrA('POP', 'ECX');
    EmitInstrA('POP', 'EBX');
    EmitInstr('RET');
    EmitBlankLine;

    { _PSPRT_COPY : ESI=src, ECX=index(1-based), EDX=count -> STRBUF }
    EmitLabel(PSP_RT_PFX + 'COPY');
    EmitInstrA('PUSH', 'EBX');
    EmitInstrA('DEC', 'ECX');
    EmitInstrAB('ADD', 'ESI', 'ECX');
    EmitInstrAB('LEA', 'EBX', PSP_RT_PFX + 'STRBUF');
    EmitLabel(PSP_RT_PFX + 'COPY_L');
    EmitInstrAB('CMP', 'EDX', '0');
    EmitInstrA('JLE', PSP_RT_PFX + 'COPY_DN');
    EmitInstrAB('MOV', 'AL', 'BYTE PTR [ESI]');
    EmitInstrAB('CMP', 'AL', '0');
    EmitInstrA('JE', PSP_RT_PFX + 'COPY_DN');
    EmitInstrAB('MOV', 'BYTE PTR [EBX]', 'AL');
    EmitInstrA('INC', 'ESI');
    EmitInstrA('INC', 'EBX');
    EmitInstrA('DEC', 'EDX');
    EmitInstrA('JMP', PSP_RT_PFX + 'COPY_L');
    EmitLabel(PSP_RT_PFX + 'COPY_DN');
    EmitInstrAB('MOV', 'BYTE PTR [EBX]', '0');
    EmitInstrAB('LEA', 'EAX', PSP_RT_PFX + 'STRBUF');
    EmitInstrA('POP', 'EBX');
    EmitInstr('RET');
    EmitBlankLine;

    { _PSPRT_POS : ESI=sub, EDI=str -> EAX (1-based, 0 si absent) }
    EmitLabel(PSP_RT_PFX + 'POS');
    EmitInstrA('PUSH', 'EBX');
    EmitInstrA('PUSH', 'ECX');
    EmitInstrAB('MOV', 'EBX', 'EDI');
    EmitInstrAB('XOR', 'ECX', 'ECX');
    EmitLabel(PSP_RT_PFX + 'POS_NX');
    EmitInstrAB('CMP', 'BYTE PTR [EBX]', '0');
    EmitInstrA('JE', PSP_RT_PFX + 'POS_NF');
    EmitInstrA('INC', 'ECX');
    EmitInstrA('PUSH', 'ESI');
    EmitInstrA('PUSH', 'EBX');
    EmitLabel(PSP_RT_PFX + 'POS_CM');
    EmitInstrAB('MOV', 'AL', 'BYTE PTR [ESI]');
    EmitInstrAB('CMP', 'AL', '0');
    EmitInstrA('JE', PSP_RT_PFX + 'POS_FD');
    EmitInstrAB('CMP', 'AL', 'BYTE PTR [EBX]');
    EmitInstrA('JNE', PSP_RT_PFX + 'POS_NM');
    EmitInstrA('INC', 'ESI');
    EmitInstrA('INC', 'EBX');
    EmitInstrA('JMP', PSP_RT_PFX + 'POS_CM');
    EmitLabel(PSP_RT_PFX + 'POS_FD');
    EmitInstrA('POP', 'EBX');
    EmitInstrA('POP', 'ESI');
    EmitInstrAB('MOV', 'EAX', 'ECX');
    EmitInstrA('JMP', PSP_RT_PFX + 'POS_DN');
    EmitLabel(PSP_RT_PFX + 'POS_NM');
    EmitInstrA('POP', 'EBX');
    EmitInstrA('POP', 'ESI');
    EmitInstrA('INC', 'EBX');
    EmitInstrA('JMP', PSP_RT_PFX + 'POS_NX');
    EmitLabel(PSP_RT_PFX + 'POS_NF');
    EmitInstrAB('XOR', 'EAX', 'EAX');
    EmitLabel(PSP_RT_PFX + 'POS_DN');
    EmitInstrA('POP', 'ECX');
    EmitInstrA('POP', 'EBX');
    EmitInstr('RET');
    EmitBlankLine;

    { _PSPRT_UPCASE : AL -> majuscule }
    EmitLabel(PSP_RT_PFX + 'UPCASE');
    EmitInstrAB('CMP', 'AL', '''a''');
    EmitInstrA('JB', PSP_RT_PFX + 'UPC_DN');
    EmitInstrAB('CMP', 'AL', '''z''');
    EmitInstrA('JA', PSP_RT_PFX + 'UPC_DN');
    EmitInstrAB('SUB', 'AL', '32');
    EmitLabel(PSP_RT_PFX + 'UPC_DN');
    EmitInstr('RET');
    EmitBlankLine;
  End;

  EmitComment('--- Fin du segment de code ---');
  EmitRaw('_TEXT   ENDS');
  EmitBlankLine;
End;

{ ---- EmitProlog : prologue de fonction 32 bits --------------- }
Procedure EmitProlog(FrameSize : Integer);
Begin
  EmitPush('EBP');
  EmitInstrAB('MOV', 'EBP', 'ESP');
  If FrameSize > 0 Then
  Begin
    EmitInstrAB('SUB', 'ESP', IntToStr(FrameSize));
    If (FrameSize > FRAME_WARN) And Opts.Warnings Then
      WarnMsg('cadre de pile volumineux : ' + IntToStr(FrameSize) +
              ' octets');
  End;
  EmitPush('ESI');
  EmitPush('EDI');
End;

{ ---- EmitEpilog : epilogue de fonction 32 bits --------------- }
Procedure EmitEpilog(ParamBytes : Integer);
Begin
  EmitPop('EDI');
  EmitPop('ESI');
  EmitInstrAB('MOV', 'ESP', 'EBP');
  EmitPop('EBP');
  If ParamBytes > 0 Then
    EmitInstrA('RET', IntToStr(ParamBytes))
  Else
    EmitInstr('RET');
End;

{ ---- EmitPush : instruction PUSH ----------------------------- }
Procedure EmitPush(Const Reg : TString);
Begin
  EmitInstrA('PUSH', Reg);
End;

{ ---- EmitPop : instruction POP ------------------------------- }
Procedure EmitPop(Const Reg : TString);
Begin
  EmitInstrA('POP', Reg);
End;

{ ---- EmitMov : instruction MOV ------------------------------- }
Procedure EmitMov(Const Dst, Src : TString);
Begin
  EmitInstrAB('MOV', Dst, Src);
End;

{ ---- EmitCall : instruction CALL ----------------------------- }
Procedure EmitCall(Const Target : TString);
Begin
  EmitInstrA('CALL', Target);
End;

{ ---- EmitJmp : instruction JMP ------------------------------- }
Procedure EmitJmp(Const Target : TString);
Begin
  EmitInstrA('JMP', Target);
End;

{ ---- EmitJmpCond : saut conditionnel (JE, JNE, JL, ...) ----- }
Procedure EmitJmpCond(Const Cond, Target : TString);
Begin
  EmitInstrA(Cond, Target);
End;

{ ---- EmitCoerce : emettre la coercition de type -------------- }
Procedure EmitCoerce(SrcType, DstType : Integer);
Var
  R : Integer;
Begin
  If SrcType <> DstType Then
  Begin
    R := TypeCoerce(SrcType, DstType);
    If R = R Then; { eviter note variable non utilisee }
  End;
End;

{ ============================================================
  TODO 08 - SEGMENT DE DONNEES ET STATIQUES [IMPLEMENTE]
  ============================================================ }
{ La majorite des fonctions de ce TODO est implementee dans les
  sections TODO 03 (DataAdd, DataAddStr, DataAddDWord, DataAddByte,
  DataAddArray, DataAddRec, LabelGen, EmitRaw, EmitDataSeg, LitEval,
  ParseConstDecl) et TODO 07 (EmitDataSeg ameliore avec les
  tampons runtime Win32, HSTDOUT, WRITTEN).
  Ci-dessous : DataAddHtml pour les fragments HTML.               }

{ ---- DataAddHtml : ajouter un fragment HTML dans DataTab ---- }
{ Cree une entree DK_STR avec le prefixe _PSPK_HTML_N.           }
{ Retourne le label genere.                                       }
Function DataAddHtml(Const Html : TString) : TString;
Var
  Lbl : TString;
Begin
  If Length(Html) = 0 Then
  Begin
    DataAddHtml := '';
    Exit;
  End;
  Inc(LabelGenSeq);
  Lbl := PSP_HTML_PFX + IntToStr(LabelGenSeq);
  DataAdd(Lbl, DK_STR, 0, Html);
  DataAddHtml := Lbl;
End;

{ ============================================================
  TODO 04 - OPERATEURS ET PRECEDENCE [IMPLEMENTE]
  ============================================================ }

{ ---- OpPrec : precedence des operateurs binaires Pascal ------ }
{ Retourne 0 si ce n est pas un operateur binaire connu.         }
{ Niveaux Pascal :                                               }
{   4 = multiplicatifs : * / div mod and shl shr                 }
{   3 = additifs       : + - or xor                              }
{   2 = comparaison    : = <> < > <= >= in                       }
{   1 = pas d operateur (seuil pour ParseExpr)                   }
Function OpPrec(Const Op : TString) : Integer;
Begin
  If (Op = '*') Or (Op = '/') Or (Op = 'div') Or (Op = 'mod') Or
     (Op = 'and') Or (Op = 'shl') Or (Op = 'shr') Then
    OpPrec := 4
  Else If (Op = '+') Or (Op = '-') Or (Op = 'or') Or (Op = 'xor') Then
    OpPrec := 3
  Else If (Op = '=') Or (Op = '<>') Or (Op = '<') Or (Op = '>') Or
          (Op = '<=') Or (Op = '>=') Or (Op = 'in') Then
    OpPrec := 2
  Else
    OpPrec := 0;
End;

{ ---- ExprMakeImm : creer une valeur immediate --------------- }
Procedure ExprMakeImm(V : LongInt; TIdx : Integer; Var R : TExprVal);
Begin
  R.Kind    := EK_IMM;
  R.ImmVal  := V;
  R.TypeIdx := TIdx;
  R.Offset  := 0;
  R.SymIdx  := -1;
End;

{ ---- ExprFlushToEAX : materialiser une expression dans EAX -- }
{ Si deja EAX, ne rien faire. Si immediate, MOV EAX, imm.       }
{ Si memoire, charger depuis variable locale ou globale.         }
Procedure ExprFlushToEAX(Var E : TExprVal);
Var
  SIdx : Integer;
Begin
  Case E.Kind Of
    EK_IMM :
    Begin
      If E.ImmVal = 0 Then
        EmitInstrAB('XOR', 'EAX', 'EAX')
      Else
        EmitInstrAB('MOV', 'EAX', IntToStr(E.ImmVal));
      E.Kind := EK_AX;
    End;
    EK_AX :
      ; { deja dans EAX }
    EK_MEM :
    Begin
      SIdx := E.SymIdx;
      If (SIdx >= 0) And (SIdx < SymCount) Then
      Begin
        If SymTab[SIdx].IsLocal Then
        Begin
          { Variable locale : MOV EAX, [EBP-n] }
          If SymTab[SIdx].Cat = SC_VARPARAM Then
          Begin
            { Parametre var (reference) : MOV EBX,[EBP+n] / MOV EAX,[EBX] }
            EmitInstrAB('MOV', 'EBX',
              'DWORD PTR ' + EBPOfs(SymTab[SIdx].Offset));
            EmitInstrAB('MOV', 'EAX', 'DWORD PTR [EBX]');
          End
          Else
          Begin
            If TypeSizeof(E.TypeIdx) = 1 Then
            Begin
              EmitInstrAB('XOR', 'EAX', 'EAX');
              EmitInstrAB('MOV', 'AL',
                'BYTE PTR ' + EBPOfs(SymTab[SIdx].Offset));
            End
            Else
              EmitInstrAB('MOV', 'EAX',
                'DWORD PTR ' + EBPOfs(SymTab[SIdx].Offset));
          End;
        End
        Else
        Begin
          { Variable globale : MOV EAX, [_PSP_xxx] }
          If TypeSizeof(E.TypeIdx) = 1 Then
          Begin
            EmitInstrAB('XOR', 'EAX', 'EAX');
            EmitInstrAB('MOV', 'AL',
              'BYTE PTR [' + SymTab[SIdx].MangledName + ']');
          End
          Else
            EmitInstrAB('MOV', 'EAX',
              'DWORD PTR [' + SymTab[SIdx].MangledName + ']');
        End;
      End
      Else
      Begin
        { Symbole inconnu : XOR EAX,EAX par defaut }
        EmitInstrAB('XOR', 'EAX', 'EAX');
      End;
      E.Kind := EK_AX;
    End;
    EK_NONE :
    Begin
      EmitInstrAB('XOR', 'EAX', 'EAX');
      E.Kind := EK_AX;
    End;
  End;
End;

{ ---- ParseCallArgs : evaluer et PUSH des arguments ----------- }
{ FuncIdx est l indice du symbole de la fonction dans SymTab.    }
{ Evalue chaque argument, flush dans EAX et PUSH EAX.            }
{ Pour un parametre var, empile l adresse (LEA) au lieu de la   }
{ valeur.                                                        }
{ CurToken doit etre sur ( au debut. Consomme jusqu a ).        }
Procedure ParseCallArgs(FuncIdx : Integer);
Var
  ArgExpr  : TExprVal;
  ArgCnt   : Integer;
  IsVarArg : Boolean;
  ArgSym   : Integer;
Begin
  ArgCnt := 0;
  { Consommer ( }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
    TplNextToken
  Else
    Exit;

  { Boucle sur les arguments }
  While (CurToken.Kind <> TK_EOF) And
        Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')')) Do
  Begin
    { Verifier si cet argument est un parametre var }
    IsVarArg := False;
    If (FuncIdx >= 0) And
       (SymTab[FuncIdx].Cat In [SC_FUNC, SC_PROC]) And
       (ArgCnt < SymTab[FuncIdx].ParamCnt) Then
    Begin
      If (SymTab[FuncIdx].VarParamMask And
          (LongInt(1) Shl ArgCnt)) <> 0 Then
        IsVarArg := True;
    End;

    If IsVarArg Then
    Begin
      { Parametre var : empiler l adresse de la variable }
      If CurToken.Kind = TK_IDENT Then
      Begin
        ArgSym := SymFind(CurToken.Val);
        If ArgSym >= 0 Then
        Begin
          TplNextToken;
          Case SymTab[ArgSym].Cat Of
            SC_VARPARAM :
            Begin
              { Deja une reference : passer le pointeur tel quel }
              EmitInstrAB('MOV', 'EAX',
                'DWORD PTR ' + EBPOfs(SymTab[ArgSym].Offset));
              EmitInstrA('PUSH', 'EAX');
            End;
            SC_VAR, SC_PARAM, SC_TYPED_CONST :
            Begin
              If SymTab[ArgSym].IsLocal Then
              Begin
                { Variable locale : LEA EAX, [EBP+ofs] }
                EmitInstrAB('LEA', 'EAX',
                  EBPOfs(SymTab[ArgSym].Offset));
                EmitInstrA('PUSH', 'EAX');
              End
              Else
              Begin
                { Variable globale : OFFSET }
                EmitInstrAB('MOV', 'EAX',
                  'OFFSET ' + SymTab[ArgSym].MangledName);
                EmitInstrA('PUSH', 'EAX');
              End;
            End;
          Else
            Begin
              WarnMsg('variable attendue pour parametre var');
              ParseExpr(ArgExpr);
              ExprFlushToEAX(ArgExpr);
              EmitInstrA('PUSH', 'EAX');
            End;
          End;
        End
        Else
        Begin
          WarnMsg('symbole non declare: ' + CurToken.Val);
          TplNextToken;
          EmitInstrAB('XOR', 'EAX', 'EAX');
          EmitInstrA('PUSH', 'EAX');
        End;
      End
      Else
      Begin
        WarnMsg('variable attendue pour parametre var');
        ParseExpr(ArgExpr);
        ExprFlushToEAX(ArgExpr);
        EmitInstrA('PUSH', 'EAX');
      End;
    End
    Else
    Begin
      { Parametre normal : empiler la valeur }
      ParseExpr(ArgExpr);
      ExprFlushToEAX(ArgExpr);
      EmitInstrA('PUSH', 'EAX');
    End;

    Inc(ArgCnt);
    { Virgule entre arguments }
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
      TplNextToken;
  End;

  { Consommer ) }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
    TplNextToken;

  If Opts.DebugMode Then
    WriteLn('  CALL_ARGS: ', ArgCnt, ' argument(s)');
End;

{ ---- ParsePrimary : token primaire -> TExprVal --------------- }
{ Gere : litteraux (entier, reel, chaine, char, true/false/nil), }
{        identificateurs (variable, constante, appel fonction),  }
{        sous-expression parenthesee (expr),                     }
{        transtypage : Integer(expr), Char(expr), etc.           }
Procedure ParsePrimary(Var Res : TExprVal);
Var
  CastTypeIdx : Integer;
  LblUC       : String;
  BaseTIdx    : Integer;
  Idx         : Integer;
  ArrTIdx     : Integer;
  IdxExpr     : TExprVal;
  ArrLo       : LongInt;
  ElemSz      : Integer;
  RecTIdx     : Integer;
  FldIdx      : Integer;
  FI          : Integer;
  FldTIdx     : Integer;
  FldSz       : Integer;
  WIdx        : Integer;
  WI          : Integer;
Begin
  Res.Kind    := EK_NONE;
  Res.ImmVal  := 0;
  Res.TypeIdx := TY_UNKNOWN;
  Res.Offset  := 0;
  Res.SymIdx  := -1;

  Case CurToken.Kind Of
    { Litteraux numeriques }
    TK_INTEGER, TK_REAL, TK_CHAR :
    Begin
      LitEval(CurToken, Res);
      TplNextToken;
    End;

    { Chaine litterale }
    TK_STRING :
    Begin
      LitEval(CurToken, Res);
      { Emettre LEA EAX, label de la chaine }
      If (Res.SymIdx >= 0) And (Res.SymIdx < DataCount) Then
        EmitInstrAB('LEA', 'EAX', DataTab[Res.SymIdx].LblName)
      Else If DataCount > 0 Then
        EmitInstrAB('LEA', 'EAX', DataTab[DataCount - 1].LblName);
      Res.Kind := EK_AX;
      TplNextToken;
    End;

    { Mots-cles speciaux : true, false, nil, transtypage }
    TK_KEYWORD :
    Begin
      If (CurToken.Val = 'true') Or (CurToken.Val = 'false') Or
         (CurToken.Val = 'nil') Then
      Begin
        LitEval(CurToken, Res);
        TplNextToken;
      End
      { Transtypage : Integer(expr), Char(expr), Byte(expr), Word(expr) }
      Else If (CurToken.Val = 'integer') Or (CurToken.Val = 'word') Or
              (CurToken.Val = 'byte') Or (CurToken.Val = 'char') Then
      Begin
        CastTypeIdx := TypeResolve(CurToken.Val);
        TplNextToken;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
        Begin
          TplNextToken;
          ParseExpr(Res);
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
            TplNextToken;
          Res.TypeIdx := CastTypeIdx;
          If Res.Kind <> EK_IMM Then
          Begin
            ExprFlushToEAX(Res);
            If (CastTypeIdx = TY_IDX_BYTE) Or
               (CastTypeIdx = TY_IDX_CHAR) Then
              EmitInstrAB('AND', 'EAX', '000000FFh');
            Res.Kind := EK_AX;
          End
          Else
          Begin
            If (CastTypeIdx = TY_IDX_BYTE) Or
               (CastTypeIdx = TY_IDX_CHAR) Then
              Res.ImmVal := Res.ImmVal And $FF;
          End;
          If Opts.DebugMode Then
            WriteLn('  TYPECAST -> type ', CastTypeIdx);
        End
        Else
          WarnMsg('''('' attendu apres le type dans le transtypage');
      End
      Else
      Begin
        WarnMsg('mot-cle inattendu dans expression: ' + CurToken.Val);
        TplNextToken;
      End;
    End;

    { Identificateur (variable, constante nommee, appel fonction) }
    TK_IDENT :
    Begin
      { --- Fonctions builtin string --- }
      If StrLowerCase(CurToken.Val) = 'length' Then
      Begin
        TplNextToken;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
          TplNextToken;
        Idx := -1;
        If (CurToken.Kind = TK_IDENT) Then
          Idx := SymFind(CurToken.Val);
        If (Idx >= 0) And
           (SymTab[Idx].TypeIdx >= 0) And
           (SymTab[Idx].TypeIdx < TypeCount) And
           (TypeTab[SymTab[Idx].TypeIdx].Kind = TKP_ARRAY) Then
        Begin
          ArrTIdx := SymTab[Idx].TypeIdx;
          EmitInstrAB('MOV', 'EAX',
            IntToStr(TypeTab[ArrTIdx].Hi - TypeTab[ArrTIdx].Lo + 1));
          TplNextToken;
        End
        Else
        Begin
          ParseExpr(Res);
          ExprFlushToEAX(Res);
          EmitInstrAB('MOV', 'ESI', 'EAX');
          EmitInstrA('CALL', PSP_RT_PFX + 'STRLEN');
        End;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          TplNextToken;
        Res.Kind    := EK_AX;
        Res.TypeIdx := TY_IDX_INTEGER;
        Res.SymIdx  := -1;
      End
      Else If StrLowerCase(CurToken.Val) = 'chr' Then
      Begin
        TplNextToken;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
          TplNextToken;
        ParseExpr(Res);
        ExprFlushToEAX(Res);
        EmitInstrA('CALL', PSP_RT_PFX + 'CHR');
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          TplNextToken;
        Res.Kind    := EK_AX;
        Res.TypeIdx := TY_IDX_STRING;
        Res.SymIdx  := -1;
      End
      Else If StrLowerCase(CurToken.Val) = 'ord' Then
      Begin
        TplNextToken;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
          TplNextToken;
        ParseExpr(Res);
        ExprFlushToEAX(Res);
        If Res.TypeIdx = TY_IDX_STRING Then
        Begin
          EmitInstrAB('MOV', 'ESI', 'EAX');
          EmitInstrAB('XOR', 'EAX', 'EAX');
          EmitInstrAB('MOV', 'AL', 'BYTE PTR [ESI]');
        End
        Else
          EmitInstrAB('AND', 'EAX', '000000FFh');
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          TplNextToken;
        Res.Kind    := EK_AX;
        Res.TypeIdx := TY_IDX_INTEGER;
        Res.SymIdx  := -1;
      End
      Else If StrLowerCase(CurToken.Val) = 'inttostr' Then
      Begin
        TplNextToken;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
          TplNextToken;
        ParseExpr(Res);
        ExprFlushToEAX(Res);
        EmitInstrA('CALL', PSP_RT_PFX + 'NUMTOSTR');
        EmitInstrAB('LEA', 'EAX', PSP_RT_PFX + 'NUMBUF');
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          TplNextToken;
        Res.Kind    := EK_AX;
        Res.TypeIdx := TY_IDX_STRING;
        Res.SymIdx  := -1;
      End
      Else If StrLowerCase(CurToken.Val) = 'strtoint' Then
      Begin
        TplNextToken;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
          TplNextToken;
        ParseExpr(Res);
        ExprFlushToEAX(Res);
        EmitInstrAB('MOV', 'ESI', 'EAX');
        EmitInstrA('CALL', PSP_RT_PFX + 'STRTONUM');
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          TplNextToken;
        Res.Kind    := EK_AX;
        Res.TypeIdx := TY_IDX_INTEGER;
        Res.SymIdx  := -1;
      End
      Else If StrLowerCase(CurToken.Val) = 'upcase' Then
      Begin
        TplNextToken;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
          TplNextToken;
        ParseExpr(Res);
        ExprFlushToEAX(Res);
        LblUC := LabelGen;
        EmitInstrAB('CMP', 'AL', '''a''');
        EmitInstrA('JB', LblUC);
        EmitInstrAB('CMP', 'AL', '''z''');
        EmitInstrA('JA', LblUC);
        EmitInstrAB('AND', 'AL', '0DFh');
        EmitLabel(LblUC);
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          TplNextToken;
        Res.Kind    := EK_AX;
        Res.TypeIdx := TY_IDX_CHAR;
        Res.SymIdx  := -1;
      End
      Else If StrLowerCase(CurToken.Val) = 'copy' Then
      Begin
        TplNextToken;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
          TplNextToken;
        ParseExpr(Res); ExprFlushToEAX(Res);
        EmitInstrAB('MOV', 'ESI', 'EAX');
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
          TplNextToken;
        ParseExpr(Res); ExprFlushToEAX(Res);
        EmitInstrA('PUSH', 'EAX');
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
          TplNextToken;
        ParseExpr(Res); ExprFlushToEAX(Res);
        EmitInstrAB('MOV', 'ECX', 'EAX');
        EmitInstrA('POP', 'EBX');
        EmitInstrA('CALL', PSP_RT_PFX + 'COPY');
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          TplNextToken;
        Res.Kind    := EK_AX;
        Res.TypeIdx := TY_IDX_STRING;
        Res.SymIdx  := -1;
      End
      Else If StrLowerCase(CurToken.Val) = 'pos' Then
      Begin
        TplNextToken;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
          TplNextToken;
        ParseExpr(Res); ExprFlushToEAX(Res);
        EmitInstrA('PUSH', 'EAX');
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
          TplNextToken;
        ParseExpr(Res); ExprFlushToEAX(Res);
        EmitInstrAB('MOV', 'EDI', 'EAX');
        EmitInstrA('POP', 'ESI');
        EmitInstrA('CALL', PSP_RT_PFX + 'POS');
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          TplNextToken;
        Res.Kind    := EK_AX;
        Res.TypeIdx := TY_IDX_INTEGER;
        Res.SymIdx  := -1;
      End
      Else If StrLowerCase(CurToken.Val) = 'concat' Then
      Begin
        TplNextToken;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
          TplNextToken;
        ParseExpr(Res); ExprFlushToEAX(Res);
        While (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Do
        Begin
          TplNextToken;
          EmitInstrAB('MOV', 'ESI', 'EAX');
          EmitInstrA('PUSH', 'ESI');
          ParseExpr(Res); ExprFlushToEAX(Res);
          EmitInstrAB('MOV', 'EDI', 'EAX');
          EmitInstrA('POP', 'ESI');
          EmitInstrA('CALL', PSP_RT_PFX + 'CONCAT');
        End;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          TplNextToken;
        Res.Kind    := EK_AX;
        Res.TypeIdx := TY_IDX_STRING;
        Res.SymIdx  := -1;
      End
      Else If StrLowerCase(CurToken.Val) = 'succ' Then
      Begin
        TplNextToken;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
          TplNextToken;
        ParseExpr(Res);
        ExprFlushToEAX(Res);
        EmitInstrA('INC', 'EAX');
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          TplNextToken;
        Res.Kind    := EK_AX;
        If Res.TypeIdx = TY_UNKNOWN Then
          Res.TypeIdx := TY_IDX_INTEGER;
        Res.SymIdx  := -1;
      End
      Else If StrLowerCase(CurToken.Val) = 'pred' Then
      Begin
        TplNextToken;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
          TplNextToken;
        ParseExpr(Res);
        ExprFlushToEAX(Res);
        EmitInstrA('DEC', 'EAX');
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          TplNextToken;
        Res.Kind    := EK_AX;
        If Res.TypeIdx = TY_UNKNOWN Then
          Res.TypeIdx := TY_IDX_INTEGER;
        Res.SymIdx  := -1;
      End
      Else If StrLowerCase(CurToken.Val) = 'low' Then
      Begin
        TplNextToken;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
          TplNextToken;
        If (CurToken.Kind = TK_IDENT) Or (CurToken.Kind = TK_KEYWORD) Then
        Begin
          BaseTIdx := TypeResolve(CurToken.Val);
          If BaseTIdx = TY_UNKNOWN Then
          Begin
            Idx := SymFind(CurToken.Val);
            If Idx >= 0 Then
              BaseTIdx := SymTab[Idx].TypeIdx
            Else
              BaseTIdx := TY_IDX_INTEGER;
          End;
          TplNextToken;
          If (BaseTIdx >= 0) And (BaseTIdx < TypeCount) Then
            Res.ImmVal := TypeTab[BaseTIdx].Lo
          Else
            Res.ImmVal := 0;
          EmitInstrAB('MOV', 'EAX', IntToStr(Res.ImmVal));
        End
        Else
        Begin
          WarnMsg('type ou variable attendu pour Low');
          EmitInstrAB('XOR', 'EAX', 'EAX');
          Res.ImmVal := 0;
        End;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          TplNextToken;
        Res.Kind    := EK_AX;
        Res.TypeIdx := TY_IDX_INTEGER;
        Res.SymIdx  := -1;
      End
      Else If StrLowerCase(CurToken.Val) = 'high' Then
      Begin
        TplNextToken;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
          TplNextToken;
        If (CurToken.Kind = TK_IDENT) Or (CurToken.Kind = TK_KEYWORD) Then
        Begin
          BaseTIdx := TypeResolve(CurToken.Val);
          If BaseTIdx = TY_UNKNOWN Then
          Begin
            Idx := SymFind(CurToken.Val);
            If Idx >= 0 Then
              BaseTIdx := SymTab[Idx].TypeIdx
            Else
              BaseTIdx := TY_IDX_INTEGER;
          End;
          TplNextToken;
          If (BaseTIdx >= 0) And (BaseTIdx < TypeCount) Then
            Res.ImmVal := TypeTab[BaseTIdx].Hi
          Else
            Res.ImmVal := 0;
          EmitInstrAB('MOV', 'EAX', IntToStr(Res.ImmVal));
        End
        Else
        Begin
          WarnMsg('type ou variable attendu pour High');
          EmitInstrAB('XOR', 'EAX', 'EAX');
          Res.ImmVal := 0;
        End;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          TplNextToken;
        Res.Kind    := EK_AX;
        Res.TypeIdx := TY_IDX_INTEGER;
        Res.SymIdx  := -1;
      End
      Else If StrLowerCase(CurToken.Val) = 'sizeof' Then
      Begin
        TplNextToken;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
          TplNextToken;
        If (CurToken.Kind = TK_IDENT) Or (CurToken.Kind = TK_KEYWORD) Then
        Begin
          BaseTIdx := TypeResolve(CurToken.Val);
          If BaseTIdx = TY_UNKNOWN Then
          Begin
            Idx := SymFind(CurToken.Val);
            If Idx >= 0 Then
              BaseTIdx := SymTab[Idx].TypeIdx
            Else
              BaseTIdx := TY_IDX_INTEGER;
          End;
          TplNextToken;
          Res.ImmVal := TypeSizeof(BaseTIdx);
          EmitInstrAB('MOV', 'EAX', IntToStr(Res.ImmVal));
        End
        Else
        Begin
          WarnMsg('type ou variable attendu pour SizeOf');
          EmitInstrAB('XOR', 'EAX', 'EAX');
          Res.ImmVal := 0;
        End;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          TplNextToken;
        Res.Kind    := EK_AX;
        Res.TypeIdx := TY_IDX_INTEGER;
        Res.SymIdx  := -1;
      End
      Else If StrLowerCase(CurToken.Val) = 'abs' Then
      Begin
        TplNextToken;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
          TplNextToken;
        ParseExpr(Res);
        ExprFlushToEAX(Res);
        EmitInstr('CDQ');
        EmitInstrAB('XOR', 'EAX', 'EDX');
        EmitInstrAB('SUB', 'EAX', 'EDX');
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          TplNextToken;
        Res.Kind    := EK_AX;
        Res.TypeIdx := TY_IDX_INTEGER;
        Res.SymIdx  := -1;
      End
      Else If StrLowerCase(CurToken.Val) = 'sqr' Then
      Begin
        TplNextToken;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
          TplNextToken;
        ParseExpr(Res);
        ExprFlushToEAX(Res);
        EmitInstrAB('IMUL', 'EAX', 'EAX');
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          TplNextToken;
        Res.Kind    := EK_AX;
        Res.TypeIdx := TY_IDX_INTEGER;
        Res.SymIdx  := -1;
      End
      Else If StrLowerCase(CurToken.Val) = 'odd' Then
      Begin
        TplNextToken;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
          TplNextToken;
        ParseExpr(Res);
        ExprFlushToEAX(Res);
        EmitInstrAB('AND', 'EAX', '1');
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          TplNextToken;
        Res.Kind    := EK_AX;
        Res.TypeIdx := TY_IDX_INTEGER;
        Res.SymIdx  := -1;
      End
      Else If StrLowerCase(CurToken.Val) = 'lo' Then
      Begin
        TplNextToken;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
          TplNextToken;
        ParseExpr(Res);
        ExprFlushToEAX(Res);
        EmitInstrAB('AND', 'EAX', '000000FFh');
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          TplNextToken;
        Res.Kind    := EK_AX;
        Res.TypeIdx := TY_IDX_INTEGER;
        Res.SymIdx  := -1;
      End
      Else If StrLowerCase(CurToken.Val) = 'hi' Then
      Begin
        TplNextToken;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
          TplNextToken;
        ParseExpr(Res);
        ExprFlushToEAX(Res);
        EmitInstrAB('SHR', 'EAX', '8');
        EmitInstrAB('AND', 'EAX', '000000FFh');
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          TplNextToken;
        Res.Kind    := EK_AX;
        Res.TypeIdx := TY_IDX_INTEGER;
        Res.SymIdx  := -1;
      End
      Else If StrLowerCase(CurToken.Val) = 'swap' Then
      Begin
        TplNextToken;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
          TplNextToken;
        ParseExpr(Res);
        ExprFlushToEAX(Res);
        EmitInstrAB('XCHG', 'AL', 'AH');
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          TplNextToken;
        Res.Kind    := EK_AX;
        Res.TypeIdx := TY_IDX_INTEGER;
        Res.SymIdx  := -1;
      End
      Else If StrLowerCase(CurToken.Val) = 'sqrt' Then
      Begin
        TplNextToken;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
          TplNextToken;
        ParseExpr(Res);
        ExprFlushToEAX(Res);
        EmitInstrA('CALL', PSP_RT_PFX + 'SQRT');
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          TplNextToken;
        Res.Kind    := EK_AX;
        Res.TypeIdx := TY_IDX_INTEGER;
        Res.SymIdx  := -1;
      End
      Else If StrLowerCase(CurToken.Val) = 'random' Then
      Begin
        TplNextToken;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
        Begin
          TplNextToken;
          ParseExpr(Res);
          ExprFlushToEAX(Res);
          EmitInstrA('PUSH', 'EAX');
          EmitInstrA('CALL', PSP_RT_PFX + 'RANDOM');
          EmitInstrA('POP', 'ECX');
          EmitInstrAB('XOR', 'EDX', 'EDX');
          EmitInstrA('DIV', 'ECX');
          EmitInstrAB('MOV', 'EAX', 'EDX');
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
            TplNextToken;
        End
        Else
          EmitInstrA('CALL', PSP_RT_PFX + 'RANDOM');
        Res.Kind    := EK_AX;
        Res.TypeIdx := TY_IDX_INTEGER;
        Res.SymIdx  := -1;
      End
      Else If StrLowerCase(CurToken.Val) = 'lowercase' Then
      Begin
        TplNextToken;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
          TplNextToken;
        ParseExpr(Res);
        ExprFlushToEAX(Res);
        EmitInstrAB('MOV', 'ESI', 'EAX');
        EmitInstrA('CALL', PSP_RT_PFX + 'LOWERCASE');
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          TplNextToken;
        Res.Kind    := EK_AX;
        Res.TypeIdx := TY_IDX_STRING;
        Res.SymIdx  := -1;
      End
      Else If StrLowerCase(CurToken.Val) = 'trim' Then
      Begin
        TplNextToken;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
          TplNextToken;
        ParseExpr(Res);
        ExprFlushToEAX(Res);
        EmitInstrAB('MOV', 'ESI', 'EAX');
        EmitInstrA('CALL', PSP_RT_PFX + 'TRIM');
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          TplNextToken;
        Res.Kind    := EK_AX;
        Res.TypeIdx := TY_IDX_STRING;
        Res.SymIdx  := -1;
      End
      Else If StrLowerCase(CurToken.Val) = 'eof' Then
      Begin
        TplNextToken;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
        Begin
          TplNextToken;
          While (CurToken.Kind <> TK_PUNCT) Or (CurToken.Val <> ')') Do
          Begin
            If CurToken.Kind = TK_EOF Then Break;
            TplNextToken;
          End;
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
            TplNextToken;
        End;
        EmitInstrAB('MOV', 'EAX', '1');
        Res.Kind    := EK_AX;
        Res.TypeIdx := TY_IDX_BOOLEAN;
        Res.SymIdx  := -1;
      End
      Else If StrLowerCase(CurToken.Val) = 'eoln' Then
      Begin
        TplNextToken;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
        Begin
          TplNextToken;
          While (CurToken.Kind <> TK_PUNCT) Or (CurToken.Val <> ')') Do
          Begin
            If CurToken.Kind = TK_EOF Then Break;
            TplNextToken;
          End;
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
            TplNextToken;
        End;
        EmitInstrAB('MOV', 'EAX', '1');
        Res.Kind    := EK_AX;
        Res.TypeIdx := TY_IDX_BOOLEAN;
        Res.SymIdx  := -1;
      End
      Else If StrLowerCase(CurToken.Val) = 'paramcount' Then
      Begin
        TplNextToken;
        WarnMsg('ParamCount : stub, retourne 0');
        EmitInstrAB('XOR', 'EAX', 'EAX');
        Res.Kind    := EK_AX;
        Res.TypeIdx := TY_IDX_INTEGER;
        Res.SymIdx  := -1;
      End
      Else If StrLowerCase(CurToken.Val) = 'paramstr' Then
      Begin
        TplNextToken;
        WarnMsg('ParamStr : stub, retourne chaine vide');
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
        Begin
          TplNextToken;
          ParseExpr(Res);
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
            TplNextToken;
        End;
        EmitInstrAB('LEA', 'EAX', PSP_RT_PFX + 'CRLF + 2');
        Res.Kind    := EK_AX;
        Res.TypeIdx := TY_IDX_STRING;
        Res.SymIdx  := -1;
      End
      Else If StrLowerCase(CurToken.Val) = 'getenv' Then
      Begin
        TplNextToken;
        WarnMsg('GetEnv : stub, retourne chaine vide');
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
        Begin
          TplNextToken;
          ParseExpr(Res);
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
            TplNextToken;
        End;
        EmitInstrAB('LEA', 'EAX', PSP_RT_PFX + 'CRLF + 2');
        Res.Kind    := EK_AX;
        Res.TypeIdx := TY_IDX_STRING;
        Res.SymIdx  := -1;
      End

      Else
      Begin
      { --- Fin fonctions builtin, debut gestion ident standard --- }
      { --- Resolution with-stack pour lecture champ --- }
      WIdx := -1;
      If WithTop >= 0 Then
      Begin
        For WI := WithTop DownTo 0 Do
        Begin
          RecTIdx := SymTab[WithSymIdx[WI]].TypeIdx;
          For FI := 0 To TypeTab[RecTIdx].FieldCount - 1 Do
            If StrLowerCase(TypeTab[RecTIdx].Fields[FI].Name) =
               StrLowerCase(CurToken.Val) Then
            Begin
              WIdx := WI;
              FldIdx := FI;
              Break;
            End;
          If WIdx >= 0 Then Break;
        End;
      End;
      If WIdx >= 0 Then
      Begin
        RecTIdx := SymTab[WithSymIdx[WIdx]].TypeIdx;
        If SymTab[WithSymIdx[WIdx]].IsLocal Then
          EmitInstrAB('LEA', 'EBX',
            EBPOfs(SymTab[WithSymIdx[WIdx]].Offset))
        Else
          EmitInstrAB('MOV', 'EBX',
            'OFFSET ' + SymTab[WithSymIdx[WIdx]].MangledName);
        If TypeTab[RecTIdx].Fields[FldIdx].Offset > 0 Then
          EmitInstrAB('ADD', 'EBX',
            IntToStr(TypeTab[RecTIdx].Fields[FldIdx].Offset));
        FldTIdx := TypeTab[RecTIdx].Fields[FldIdx].TypeIdx;
        FldSz   := TypeSizeof(FldTIdx);
        If FldSz = 1 Then
        Begin
          EmitInstrAB('XOR', 'EAX', 'EAX');
          EmitInstrAB('MOV', 'AL', 'BYTE PTR [EBX]');
        End
        Else
          EmitInstrAB('MOV', 'EAX', 'DWORD PTR [EBX]');
        Res.Kind    := EK_AX;
        Res.TypeIdx := FldTIdx;
        Res.SymIdx  := -1;
        TplNextToken;
      End
      Else
      Begin
      { --- Resolution standard ident --- }
      Res.SymIdx := SymFind(CurToken.Val);
      If Res.SymIdx >= 0 Then
      Begin
        If Opts.DebugMode Then
          WriteLn('  EXPR_IDENT: ', CurToken.Val,
                  ' -> sym[', Res.SymIdx, '] cat=',
                  Ord(SymTab[Res.SymIdx].Cat));
        Case SymTab[Res.SymIdx].Cat Of
          SC_CONST :
          Begin
            Res.Kind    := EK_IMM;
            Res.ImmVal  := SymTab[Res.SymIdx].ImmVal;
            Res.TypeIdx := SymTab[Res.SymIdx].TypeIdx;
          End;
          SC_TYPED_CONST :
          Begin
            Res.Kind    := EK_IMM;
            Res.ImmVal  := SymTab[Res.SymIdx].ImmVal;
            Res.TypeIdx := SymTab[Res.SymIdx].TypeIdx;
          End;
          SC_VAR, SC_PARAM, SC_VARPARAM :
          Begin
            Res.Kind    := EK_MEM;
            Res.ImmVal  := 0;
            Res.TypeIdx := SymTab[Res.SymIdx].TypeIdx;
            Res.Offset  := SymTab[Res.SymIdx].Offset;
          End;
          SC_FUNC :
          Begin
            Res.Kind    := EK_AX;
            Res.ImmVal  := 0;
            Res.TypeIdx := SymTab[Res.SymIdx].TypeIdx;
          End;
          SC_ENUM_VAL :
          Begin
            Res.Kind    := EK_IMM;
            Res.ImmVal  := SymTab[Res.SymIdx].ImmVal;
            Res.TypeIdx := SymTab[Res.SymIdx].TypeIdx;
          End;
        Else
          Res.Kind    := EK_MEM;
          Res.ImmVal  := 0;
          Res.TypeIdx := TY_IDX_INTEGER;
        End;
      End
      Else
      Begin
        WarnMsg('symbole non declare: ' + CurToken.Val);
        Res.Kind    := EK_MEM;
        Res.ImmVal  := 0;
        Res.TypeIdx := TY_IDX_INTEGER;
        Res.SymIdx  := -1;
      End;
      TplNextToken;
      { --- Detecter acces champ record : ident.field --- }
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '.') Then
      Begin
        If (Res.SymIdx >= 0) And (Res.SymIdx < SymCount) And
           (SymTab[Res.SymIdx].TypeIdx >= 0) And
           (SymTab[Res.SymIdx].TypeIdx < TypeCount) And
           (TypeTab[SymTab[Res.SymIdx].TypeIdx].Kind = TKP_RECORD) Then
        Begin
          RecTIdx := SymTab[Res.SymIdx].TypeIdx;
          If SymTab[Res.SymIdx].IsLocal Then
            EmitInstrAB('LEA', 'EBX',
              EBPOfs(SymTab[Res.SymIdx].Offset))
          Else
            EmitInstrAB('MOV', 'EBX',
              'OFFSET ' + SymTab[Res.SymIdx].MangledName);
          FldTIdx := TY_IDX_INTEGER;
          While (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '.') Do
          Begin
            TplNextToken;
            If CurToken.Kind = TK_IDENT Then
            Begin
              FldIdx := -1;
              For FI := 0 To TypeTab[RecTIdx].FieldCount - 1 Do
                If StrLowerCase(TypeTab[RecTIdx].Fields[FI].Name) =
                   StrLowerCase(CurToken.Val) Then
                Begin
                  FldIdx := FI;
                  Break;
                End;
              If FldIdx >= 0 Then
              Begin
                If TypeTab[RecTIdx].Fields[FldIdx].Offset > 0 Then
                  EmitInstrAB('ADD', 'EBX',
                    IntToStr(TypeTab[RecTIdx].Fields[FldIdx].Offset));
                FldTIdx := TypeTab[RecTIdx].Fields[FldIdx].TypeIdx;
                TplNextToken;
                If (FldTIdx >= 0) And (FldTIdx < TypeCount) And
                   (TypeTab[FldTIdx].Kind = TKP_RECORD) Then
                  RecTIdx := FldTIdx;
              End
              Else
              Begin
                WarnMsg('champ inconnu: ' + CurToken.Val);
                TplNextToken;
                Break;
              End;
            End
            Else
            Begin
              WarnMsg('nom de champ attendu apres "."');
              Break;
            End;
          End;
          FldSz := TypeSizeof(FldTIdx);
          If FldSz = 1 Then
          Begin
            EmitInstrAB('XOR', 'EAX', 'EAX');
            EmitInstrAB('MOV', 'AL', 'BYTE PTR [EBX]');
          End
          Else
            EmitInstrAB('MOV', 'EAX', 'DWORD PTR [EBX]');
          Res.Kind    := EK_AX;
          Res.TypeIdx := FldTIdx;
          Res.SymIdx  := -1;
        End
        Else
        Begin
          WarnMsg('acces "." sur un non-record');
          TplNextToken;
          If CurToken.Kind = TK_IDENT Then
            TplNextToken;
        End;
      End
      Else
      { --- Detecter indexation tableau : ident[ --- }
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '[') Then
      Begin
        If (Res.SymIdx >= 0) And (Res.SymIdx < SymCount) And
           (SymTab[Res.SymIdx].TypeIdx >= 0) And
           (SymTab[Res.SymIdx].TypeIdx < TypeCount) And
           (TypeTab[SymTab[Res.SymIdx].TypeIdx].Kind = TKP_ARRAY) Then
        Begin
          ArrTIdx := SymTab[Res.SymIdx].TypeIdx;
          ArrLo   := TypeTab[ArrTIdx].Lo;
          ElemSz  := TypeSizeof(TypeTab[ArrTIdx].BaseTypeIdx);
          TplNextToken;
          ParseExpr(IdxExpr);
          ExprFlushToEAX(IdxExpr);
          If ArrLo <> 0 Then
            EmitInstrAB('SUB', 'EAX', IntToStr(ArrLo));
          If ElemSz = 4 Then
            EmitInstrAB('SHL', 'EAX', '2')
          Else If ElemSz = 2 Then
            EmitInstrAB('SHL', 'EAX', '1')
          Else If (ElemSz <> 1) And (ElemSz > 4) Then
          Begin
            EmitInstrAB('MOV', 'ECX', IntToStr(ElemSz));
            EmitInstrAB('IMUL', 'EAX', 'ECX');
          End;
          If SymTab[Res.SymIdx].IsLocal Then
            EmitInstrAB('LEA', 'EBX',
              EBPOfs(SymTab[Res.SymIdx].Offset))
          Else
            EmitInstrAB('MOV', 'EBX',
              'OFFSET ' + SymTab[Res.SymIdx].MangledName);
          EmitInstrAB('ADD', 'EBX', 'EAX');
          If ElemSz = 1 Then
          Begin
            EmitInstrAB('XOR', 'EAX', 'EAX');
            EmitInstrAB('MOV', 'AL', 'BYTE PTR [EBX]');
          End
          Else
            EmitInstrAB('MOV', 'EAX', 'DWORD PTR [EBX]');
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ']') Then
            TplNextToken;
          Res.Kind    := EK_AX;
          Res.TypeIdx := TypeTab[ArrTIdx].BaseTypeIdx;
          Res.SymIdx  := -1;
        End
        Else
        Begin
          WarnMsg('indexation sur un non-tableau');
          TplNextToken;
          While (CurToken.Kind <> TK_EOF) And
                Not ((CurToken.Kind = TK_PUNCT) And
                     (CurToken.Val = ']')) Do
            TplNextToken;
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ']') Then
            TplNextToken;
        End;
      End
      { Detecter un appel de fonction : ident( }
      Else If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
      Begin
        If (Res.SymIdx >= 0) And
           (SymTab[Res.SymIdx].Cat In [SC_FUNC, SC_PROC]) Then
        Begin
          EmitComment('call ' + SymTab[Res.SymIdx].Name);
          ParseCallArgs(Res.SymIdx);
          EmitInstrA('CALL', SymTab[Res.SymIdx].MangledName);
          Res.Kind    := EK_AX;
          Res.TypeIdx := SymTab[Res.SymIdx].TypeIdx;
          Res.SymIdx  := -1;
        End
        Else
        Begin
          TplNextToken;
          While (CurToken.Kind <> TK_EOF) And
                Not ((CurToken.Kind = TK_PUNCT) And
                     (CurToken.Val = ')')) Do
            TplNextToken;
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
            TplNextToken;
          Res.Kind := EK_AX;
        End;
      End;
      End; { fin Else Begin Resolution standard ident }
      End; { fin du else (ident standard / with-stack) }
    End;

    { Sous-expression parenthesee }
    TK_PUNCT :
    Begin
      If CurToken.Val = '(' Then
      Begin
        TplNextToken;
        ParseExpr(Res);
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          TplNextToken
        Else
          WarnMsg(''')'' attendu apres expression parenthesee');
      End
      Else
      Begin
        WarnMsg('token inattendu dans expression: ' + CurToken.Val);
        TplNextToken;
      End;
    End;

  Else
    WarnMsg('expression attendue, token: ' + CurToken.Val);
    TplNextToken;
  End;
End;

{ ---- ParseUnary : operateurs unaires prefixes --------------- }
{ Niveau 1 : not, -, @                                          }
Procedure ParseUnary(Var Res : TExprVal);
Begin
  { not (logique ou bits selon type) }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'not') Then
  Begin
    TplNextToken;
    ParseUnary(Res);
    If Res.Kind = EK_IMM Then
    Begin
      If Res.TypeIdx = TY_IDX_BOOLEAN Then
      Begin
        If Res.ImmVal = 0 Then Res.ImmVal := 1
        Else Res.ImmVal := 0;
      End
      Else
        Res.ImmVal := Not Res.ImmVal;
    End
    Else
    Begin
      ExprFlushToEAX(Res);
      If Res.TypeIdx = TY_IDX_BOOLEAN Then
        EmitInstrAB('XOR', 'EAX', '1')
      Else
        EmitInstrA('NOT', 'EAX');
      Res.Kind   := EK_AX;
      Res.SymIdx := -1;
    End;
    Exit;
  End;

  { Moins unaire }
  If (CurToken.Kind = TK_OP) And (CurToken.Val = '-') Then
  Begin
    TplNextToken;
    ParseUnary(Res);
    If Res.Kind = EK_IMM Then
      Res.ImmVal := -Res.ImmVal
    Else
    Begin
      ExprFlushToEAX(Res);
      EmitInstrA('NEG', 'EAX');
      Res.Kind   := EK_AX;
      Res.SymIdx := -1;
    End;
    Exit;
  End;

  { Plus unaire (no-op) }
  If (CurToken.Kind = TK_OP) And (CurToken.Val = '+') Then
  Begin
    TplNextToken;
    ParseUnary(Res);
    Exit;
  End;

  { @ (adresse de) }
  If (CurToken.Kind = TK_OP) And (CurToken.Val = '@') Then
  Begin
    TplNextToken;
    ParsePrimary(Res);
    If (Res.SymIdx >= 0) And (Res.SymIdx < SymCount) Then
    Begin
      If SymTab[Res.SymIdx].IsLocal Then
        EmitInstrAB('LEA', 'EAX',
          EBPOfs(SymTab[Res.SymIdx].Offset))
      Else
        EmitInstrAB('MOV', 'EAX',
          'OFFSET ' + SymTab[Res.SymIdx].MangledName);
    End
    Else
    Begin
      WarnMsg('@ requiert une variable ou un parametre');
      EmitInstrAB('XOR', 'EAX', 'EAX');
    End;
    Res.Kind    := EK_AX;
    Res.TypeIdx := TY_IDX_POINTER;
    Res.SymIdx  := -1;
    Exit;
  End;

  { Pas d operateur unaire : appeler ParsePrimary }
  ParsePrimary(Res);
End;

{ ---- ParseExprPrec : Pratt parser pour operateurs binaires --- }
{ Boucle de montee de precedence.                                }
{ EAX = gauche, EBX = droite pour emission (32 bits).            }
Procedure ParseExprPrec(MinPrec : Integer; Var Res : TExprVal);
Var
  Op        : TString;
  Prec      : Integer;
  Right     : TExprVal;
  LeftIsImm : Boolean;
  LeftImm   : LongInt;
  ResType   : Integer;
  LblSkip   : TString;
Begin
  ParseUnary(Res);

  Repeat
    Op   := '';
    Prec := 0;

    { Detecter operateur binaire }
    If CurToken.Kind = TK_OP Then
    Begin
      Op   := CurToken.Val;
      Prec := OpPrec(Op);
    End
    Else If (CurToken.Kind = TK_KEYWORD) And
            ((CurToken.Val = 'div') Or (CurToken.Val = 'mod') Or
             (CurToken.Val = 'and') Or (CurToken.Val = 'or') Or
             (CurToken.Val = 'xor') Or (CurToken.Val = 'shl') Or
             (CurToken.Val = 'shr') Or (CurToken.Val = 'in')) Then
    Begin
      Op   := CurToken.Val;
      Prec := OpPrec(Op);
    End;

    { Arreter si pas operateur ou precedence insuffisante }
    If (Prec = 0) Or (Prec < MinPrec) Then Break;

    TplNextToken;  { consommer l operateur }

    { Sauvegarder operande gauche }
    LeftIsImm := (Res.Kind = EK_IMM);
    LeftImm   := Res.ImmVal;
    If Not LeftIsImm Then
    Begin
      ExprFlushToEAX(Res);
      EmitInstrA('PUSH', 'EAX');
    End;

    { Recurser cote droit (gauche-assoc : Prec + 1) }
    ParseExprPrec(Prec + 1, Right);

    { Pliage de constantes si les deux sont immediats }
    If LeftIsImm And (Right.Kind = EK_IMM) Then
    Begin
      If Op = '+' Then
        ExprMakeImm(LeftImm + Right.ImmVal, TY_IDX_INTEGER, Res)
      Else If Op = '-' Then
        ExprMakeImm(LeftImm - Right.ImmVal, TY_IDX_INTEGER, Res)
      Else If Op = '*' Then
        ExprMakeImm(LeftImm * Right.ImmVal, TY_IDX_INTEGER, Res)
      Else If (Op = '/') Or (Op = 'div') Then
      Begin
        If Right.ImmVal <> 0 Then
          ExprMakeImm(LeftImm Div Right.ImmVal, TY_IDX_INTEGER, Res)
        Else
        Begin
          WarnMsg('division par zero dans constante');
          ExprMakeImm(0, TY_IDX_INTEGER, Res);
        End;
      End
      Else If Op = 'mod' Then
      Begin
        If Right.ImmVal <> 0 Then
          ExprMakeImm(LeftImm Mod Right.ImmVal, TY_IDX_INTEGER, Res)
        Else
        Begin
          WarnMsg('modulo par zero dans constante');
          ExprMakeImm(0, TY_IDX_INTEGER, Res);
        End;
      End
      Else If Op = 'and' Then
        ExprMakeImm(LeftImm And Right.ImmVal, TY_IDX_INTEGER, Res)
      Else If Op = 'or' Then
        ExprMakeImm(LeftImm Or Right.ImmVal, TY_IDX_INTEGER, Res)
      Else If Op = 'xor' Then
        ExprMakeImm(LeftImm Xor Right.ImmVal, TY_IDX_INTEGER, Res)
      Else If Op = 'shl' Then
        ExprMakeImm(LeftImm Shl Integer(Right.ImmVal And 31),
                    TY_IDX_INTEGER, Res)
      Else If Op = 'shr' Then
        ExprMakeImm(LeftImm Shr Integer(Right.ImmVal And 31),
                    TY_IDX_INTEGER, Res)
      Else If Op = '=' Then
        ExprMakeImm(Ord(LeftImm = Right.ImmVal), TY_IDX_BOOLEAN, Res)
      Else If Op = '<>' Then
        ExprMakeImm(Ord(LeftImm <> Right.ImmVal), TY_IDX_BOOLEAN, Res)
      Else If Op = '<' Then
        ExprMakeImm(Ord(LeftImm < Right.ImmVal), TY_IDX_BOOLEAN, Res)
      Else If Op = '>' Then
        ExprMakeImm(Ord(LeftImm > Right.ImmVal), TY_IDX_BOOLEAN, Res)
      Else If Op = '<=' Then
        ExprMakeImm(Ord(LeftImm <= Right.ImmVal), TY_IDX_BOOLEAN, Res)
      Else If Op = '>=' Then
        ExprMakeImm(Ord(LeftImm >= Right.ImmVal), TY_IDX_BOOLEAN, Res)
      Else If Op = 'in' Then
      Begin
        WarnMsg('in : ensembles non supportes, retourne 0');
        ExprMakeImm(0, TY_IDX_BOOLEAN, Res);
      End
      Else
        ExprMakeImm(0, TY_IDX_INTEGER, Res);
    End
    Else
    Begin
      { ---- Emission de code binaire (32 bits) ---- }
      ResType := Res.TypeIdx;
      If (Res.TypeIdx = TY_IDX_STRING) Or (Right.TypeIdx = TY_IDX_STRING) Then
        ResType := TY_IDX_STRING
      Else If (Op = '=') Or (Op = '<>') Or (Op = '<') Or (Op = '>') Or
              (Op = '<=') Or (Op = '>=') Or (Op = 'in') Then
        ResType := TY_IDX_BOOLEAN;

      { Charger droite dans EBX }
      ExprFlushToEAX(Right);
      EmitInstrAB('MOV', 'EBX', 'EAX');

      { Restaurer gauche dans EAX }
      If LeftIsImm Then
        EmitInstrAB('MOV', 'EAX', IntToStr(LeftImm))
      Else
        EmitInstrA('POP', 'EAX');

      { EAX = gauche, EBX = droite }

      { --- Arithmetique --- }
      If Op = '+' Then
      Begin
        If ResType = TY_IDX_STRING Then
        Begin
          EmitInstrAB('MOV', 'ESI', 'EAX');
          EmitInstrAB('MOV', 'EDI', 'EBX');
          EmitInstrA('CALL', PSP_RT_PFX + 'CONCAT');
        End
        Else
          EmitInstrAB('ADD', 'EAX', 'EBX');
      End
      Else If Op = '-' Then
        EmitInstrAB('SUB', 'EAX', 'EBX')

      Else If Op = '*' Then
        EmitInstrA('IMUL', 'EBX')

      Else If (Op = '/') Or (Op = 'div') Then
      Begin
        EmitInstrAB('CMP', 'EBX', '0');
        EmitInstrA('JE', PSP_RT_PFX + 'PANIC_DIV0');
        EmitInstr('CDQ');
        EmitInstrA('IDIV', 'EBX');
      End

      Else If Op = 'mod' Then
      Begin
        EmitInstrAB('CMP', 'EBX', '0');
        EmitInstrA('JE', PSP_RT_PFX + 'PANIC_DIV0');
        EmitInstr('CDQ');
        EmitInstrA('IDIV', 'EBX');
        EmitInstrAB('MOV', 'EAX', 'EDX');
      End

      Else If Op = 'and' Then
        EmitInstrAB('AND', 'EAX', 'EBX')

      Else If Op = 'or' Then
        EmitInstrAB('OR', 'EAX', 'EBX')

      Else If Op = 'xor' Then
        EmitInstrAB('XOR', 'EAX', 'EBX')

      Else If Op = 'shl' Then
      Begin
        EmitInstrAB('MOV', 'CL', 'BL');
        EmitInstrAB('SHL', 'EAX', 'CL');
      End

      Else If Op = 'shr' Then
      Begin
        EmitInstrAB('MOV', 'CL', 'BL');
        EmitInstrAB('SHR', 'EAX', 'CL');
      End

      { --- Comparaisons : CMP + Jcc -> EAX = 0|1 --- }
      Else If Op = '=' Then
      Begin
        LblSkip := LabelGen;
        If ResType = TY_IDX_STRING Then
        Begin
          EmitInstrAB('MOV', 'ESI', 'EAX');
          EmitInstrAB('MOV', 'EDI', 'EBX');
          EmitInstrA('CALL', PSP_RT_PFX + 'STRCMP');
          EmitInstrAB('CMP', 'EAX', '0');
        End
        Else
          EmitInstrAB('CMP', 'EAX', 'EBX');
        EmitInstrAB('MOV', 'EAX', '0');
        EmitInstrA('JNE', LblSkip);
        EmitInstrA('INC', 'EAX');
        EmitLabel(LblSkip);
      End

      Else If Op = '<>' Then
      Begin
        LblSkip := LabelGen;
        If ResType = TY_IDX_STRING Then
        Begin
          EmitInstrAB('MOV', 'ESI', 'EAX');
          EmitInstrAB('MOV', 'EDI', 'EBX');
          EmitInstrA('CALL', PSP_RT_PFX + 'STRCMP');
          EmitInstrAB('CMP', 'EAX', '0');
        End
        Else
          EmitInstrAB('CMP', 'EAX', 'EBX');
        EmitInstrAB('MOV', 'EAX', '0');
        EmitInstrA('JE', LblSkip);
        EmitInstrA('INC', 'EAX');
        EmitLabel(LblSkip);
      End

      Else If Op = '<' Then
      Begin
        LblSkip := LabelGen;
        If ResType = TY_IDX_STRING Then
        Begin
          EmitInstrAB('MOV', 'ESI', 'EAX');
          EmitInstrAB('MOV', 'EDI', 'EBX');
          EmitInstrA('CALL', PSP_RT_PFX + 'STRCMP');
          EmitInstrAB('CMP', 'EAX', '0');
        End
        Else
          EmitInstrAB('CMP', 'EAX', 'EBX');
        EmitInstrAB('MOV', 'EAX', '0');
        EmitInstrA('JGE', LblSkip);
        EmitInstrA('INC', 'EAX');
        EmitLabel(LblSkip);
      End

      Else If Op = '<=' Then
      Begin
        LblSkip := LabelGen;
        If ResType = TY_IDX_STRING Then
        Begin
          EmitInstrAB('MOV', 'ESI', 'EAX');
          EmitInstrAB('MOV', 'EDI', 'EBX');
          EmitInstrA('CALL', PSP_RT_PFX + 'STRCMP');
          EmitInstrAB('CMP', 'EAX', '0');
        End
        Else
          EmitInstrAB('CMP', 'EAX', 'EBX');
        EmitInstrAB('MOV', 'EAX', '0');
        EmitInstrA('JG', LblSkip);
        EmitInstrA('INC', 'EAX');
        EmitLabel(LblSkip);
      End

      Else If Op = '>' Then
      Begin
        LblSkip := LabelGen;
        If ResType = TY_IDX_STRING Then
        Begin
          EmitInstrAB('MOV', 'ESI', 'EAX');
          EmitInstrAB('MOV', 'EDI', 'EBX');
          EmitInstrA('CALL', PSP_RT_PFX + 'STRCMP');
          EmitInstrAB('CMP', 'EAX', '0');
        End
        Else
          EmitInstrAB('CMP', 'EAX', 'EBX');
        EmitInstrAB('MOV', 'EAX', '0');
        EmitInstrA('JLE', LblSkip);
        EmitInstrA('INC', 'EAX');
        EmitLabel(LblSkip);
      End

      Else If Op = '>=' Then
      Begin
        LblSkip := LabelGen;
        If ResType = TY_IDX_STRING Then
        Begin
          EmitInstrAB('MOV', 'ESI', 'EAX');
          EmitInstrAB('MOV', 'EDI', 'EBX');
          EmitInstrA('CALL', PSP_RT_PFX + 'STRCMP');
          EmitInstrAB('CMP', 'EAX', '0');
        End
        Else
          EmitInstrAB('CMP', 'EAX', 'EBX');
        EmitInstrAB('MOV', 'EAX', '0');
        EmitInstrA('JL', LblSkip);
        EmitInstrA('INC', 'EAX');
        EmitLabel(LblSkip);
      End

      Else If Op = 'in' Then
      Begin
        EmitInstrAB('XOR', 'EAX', 'EAX');
        WarnMsg('in : ensembles non supportes, retourne 0');
      End;

      Res.Kind    := EK_AX;
      Res.TypeIdx := ResType;
      Res.SymIdx  := -1;
    End;
  Until False;
End;

{ ---- ParseExpr : point d entree pour les expressions --------- }
Procedure ParseExpr(Var Res : TExprVal);
Begin
  ParseExprPrec(1, Res);
End;

{ ============================================================
  TODO 09 - VARIABLES ET AFFECTATIONS (32 BITS) [IMPLEMENTE]
  ============================================================ }

{ ---- ExprAddrOf : retourner la chaine d adresse d un symbole - }
{ Retourne la representation MASM de l adresse :                   }
{   - locale/param -> [EBP-n] ou [EBP+n]                          }
{   - globale -> [_PSP_xxx]                                        }
Function ExprAddrOf(SIdx : Integer) : TString;
Begin
  If SymTab[SIdx].IsLocal Then
    ExprAddrOf := EBPOfs(SymTab[SIdx].Offset)
  Else
    ExprAddrOf := '[' + SymTab[SIdx].MangledName + ']';
End;

{ ---- ExprStore : stocker EAX dans la cible SIdx ------------- }
{ Gere : variable locale, globale, parametre var (double indirection) }
Procedure ExprStore(SIdx : Integer);
Var
  Sz : Integer;
Begin
  Sz := TypeSizeof(SymTab[SIdx].TypeIdx);
  If SymTab[SIdx].IsLocal Then
  Begin
    If SymTab[SIdx].Cat = SC_VARPARAM Then
    Begin
      { Parametre var (reference) : MOV EBX,[EBP+n] / MOV [EBX], EAX }
      EmitInstrAB('MOV', 'EBX',
        'DWORD PTR ' + EBPOfs(SymTab[SIdx].Offset));
      If Sz = 1 Then
        EmitInstrAB('MOV', 'BYTE PTR [EBX]', 'AL')
      Else
        EmitInstrAB('MOV', 'DWORD PTR [EBX]', 'EAX');
    End
    Else
    Begin
      { Variable locale ou parametre value : MOV [EBP-n], EAX }
      If Sz = 1 Then
        EmitInstrAB('MOV',
          'BYTE PTR ' + EBPOfs(SymTab[SIdx].Offset), 'AL')
      Else
        EmitInstrAB('MOV',
          'DWORD PTR ' + EBPOfs(SymTab[SIdx].Offset), 'EAX');
    End;
  End
  Else
  Begin
    { Variable globale : MOV [_PSP_xxx], EAX }
    If Sz = 1 Then
      EmitInstrAB('MOV',
        'BYTE PTR [' + SymTab[SIdx].MangledName + ']', 'AL')
    Else
      EmitInstrAB('MOV',
        'DWORD PTR [' + SymTab[SIdx].MangledName + ']', 'EAX');
  End;
End;

{ ---- ExprLoad : charger un symbole dans un TExprVal --------- }
Procedure ExprLoad(SIdx : Integer; Var E : TExprVal);
Begin
  E.Kind    := EK_MEM;
  E.ImmVal  := 0;
  E.TypeIdx := SymTab[SIdx].TypeIdx;
  E.Offset  := SymTab[SIdx].Offset;
  E.SymIdx  := SIdx;
End;

{ ---- DeclAllocGlobal : allouer une variable globale --------- }
{ Cree une entree dans DataTab et met a jour le symbole.          }
Function DeclAllocGlobal(Const Name : TString;
                TIdx : Integer) : Integer;
Var
  SIdx, DIdx : Integer;
  TSz : Integer;
Begin
  SIdx := SymAdd(Name, SC_VAR, TIdx);
  DeclAllocGlobal := SIdx;
  If SIdx < 0 Then Exit;
  TSz := TypeSizeof(TIdx);
  { Records }
  If (TIdx >= 0) And (TIdx < TypeCount) And
     (TypeTab[TIdx].Kind = TKP_RECORD) Then
  Begin
    SymTab[SIdx].MangledName := PSP_REC_PFX +
      StrUpperCase(Name);
    DIdx := DataAddRec(SymTab[SIdx].MangledName, TSz);
    SymTab[SIdx].DataIdx := DIdx;
    SymTab[SIdx].IsLocal := False;
  End
  Else If TSz = 1 Then
  Begin
    DIdx := DataAddByte(SymTab[SIdx].MangledName, 0);
    SymTab[SIdx].DataIdx := DIdx;
    SymTab[SIdx].IsLocal := False;
  End
  Else
  Begin
    DIdx := DataAddDWord(SymTab[SIdx].MangledName, 0);
    SymTab[SIdx].DataIdx := DIdx;
    SymTab[SIdx].IsLocal := False;
  End;
  If Opts.DebugMode Then
    WriteLn('  VAR_GLOBAL: ', Name, ' -> ',
            SymTab[SIdx].MangledName);
End;

{ ---- DeclAllocLocal : allouer une variable locale ----------- }
{ Decremente CurFrameOffset et stocke l offset dans le symbole.  }
Function DeclAllocLocal(Const Name : TString;
                TIdx : Integer) : Integer;
Var
  SIdx : Integer;
  TSz  : Integer;
Begin
  SIdx := SymAdd(Name, SC_VAR, TIdx);
  DeclAllocLocal := SIdx;
  If SIdx < 0 Then Exit;
  TSz := TypeSizeof(TIdx);
  { Aligner Byte/Char/Boolean sur 4 octets (DWORD) }
  If TSz < 4 Then
    TSz := 4;
  Dec(CurFrameOffset, TSz);
  SymTab[SIdx].Offset  := CurFrameOffset;
  SymTab[SIdx].IsLocal := True;
  If Opts.DebugMode Then
    WriteLn('  VAR_LOCAL: ', Name, ' -> ',
            EBPOfs(CurFrameOffset));
End;

{ ---- ParseVarDecl : analyser un bloc var ---------------------- }
{ Syntaxe : var a, b, c: Integer; s: String;                      }
{ Gere les declarations multiples sur une meme ligne.             }
{ Scope global -> entree DataTab, scope local -> offset cadre.    }
Procedure ParseVarDecl;
Var
  Names    : Array[0..MAX_PARAM - 1] Of TString;
  NCount   : Integer;
  TName    : TString;
  TIdx     : Integer;
  I, Idx   : Integer;
  DIdx     : Integer;
  { Tableaux }
  ArrLo, ArrHi   : LongInt;
  ArrCount        : LongInt;
  ArrSize         : LongInt;
  ElemTIdx        : Integer;
  NewArrTIdx      : Integer;
  ElemTName       : TString;
  ElemSz          : Integer;
Begin
  { Le mot-cle 'var' a deja ete consomme par l appelant }
  HasPendingAssign := False;
  While (CurToken.Kind = TK_IDENT) Do
  Begin
    { Lookahead : lire le premier ident puis verifier le token suivant }
    Names[0] := CurToken.Val;
    NCount := 1;
    TplNextToken;

    { Si := suit, c est une affectation, pas une declaration var }
    If (CurToken.Kind = TK_OP) And (CurToken.Val = ':=') Then
    Begin
      PendingAssignName := Names[0];
      HasPendingAssign  := True;
      Exit;  { Quitter ParseVarDecl, laisser CurToken sur := }
    End;

    { Collecter d eventuels noms supplementaires separes par virgule }
    While (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Do
    Begin
      TplNextToken;
      If CurToken.Kind = TK_IDENT Then
      Begin
        If NCount < MAX_PARAM Then
        Begin
          Names[NCount] := CurToken.Val;
          Inc(NCount);
        End
        Else
          WarnMsg('trop de variables dans une declaration');
        TplNextToken;
      End
      Else
      Begin
        WarnMsg('identificateur attendu apres virgule');
        Break;
      End;
    End;

    { Deux-points + nom de type }
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ':') Then
      TplNextToken
    Else
    Begin
      WarnMsg(''':'' attendu apres le(s) nom(s) de variable');
      { Sauter jusqu au prochain ; }
      While (CurToken.Kind <> TK_EOF) And
            Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';')) Do
        TplNextToken;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
        TplNextToken;
      Continue;
    End;

    { --- Detection array[lo..hi] of TypeElem --- }
    If (CurToken.Kind = TK_KEYWORD) And
       (StrLowerCase(CurToken.Val) = 'array') Then
    Begin
      TplNextToken;  { consommer array }

      { Consommer [ }
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '[') Then
        TplNextToken
      Else
        WarnMsg('''['' attendu apres array');

      { Borne inferieure }
      ArrLo := 0;
      If CurToken.Kind = TK_INTEGER Then
      Begin
        ArrLo := CurToken.IntVal;
        TplNextToken;
      End
      Else If (CurToken.Kind = TK_IDENT) Or
              (CurToken.Kind = TK_KEYWORD) Then
      Begin
        Idx := SymFind(CurToken.Val);
        If (Idx >= 0) And
           (SymTab[Idx].Cat In [SC_CONST, SC_ENUM_VAL]) Then
          ArrLo := SymTab[Idx].ImmVal
        Else
          WarnMsg('constante attendue pour borne inferieure');
        TplNextToken;
      End;

      { Consommer .. }
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '..') Then
        TplNextToken
      Else
        WarnMsg('''..'' attendu dans declaration array');

      { Borne superieure }
      ArrHi := 0;
      If CurToken.Kind = TK_INTEGER Then
      Begin
        ArrHi := CurToken.IntVal;
        TplNextToken;
      End
      Else If (CurToken.Kind = TK_IDENT) Or
              (CurToken.Kind = TK_KEYWORD) Then
      Begin
        Idx := SymFind(CurToken.Val);
        If (Idx >= 0) And
           (SymTab[Idx].Cat In [SC_CONST, SC_ENUM_VAL]) Then
          ArrHi := SymTab[Idx].ImmVal
        Else
          WarnMsg('constante attendue pour borne superieure');
        TplNextToken;
      End;

      { Consommer ] }
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ']') Then
        TplNextToken
      Else
        WarnMsg(''']'' attendu');

      { Consommer of }
      If (CurToken.Kind = TK_KEYWORD) And
         (StrLowerCase(CurToken.Val) = 'of') Then
        TplNextToken
      Else
        WarnMsg('''of'' attendu apres array[...]');

      { Lire le type element }
      ElemTName := '';
      If (CurToken.Kind = TK_KEYWORD) Or
         (CurToken.Kind = TK_IDENT) Then
      Begin
        ElemTName := CurToken.Val;
        TplNextToken;
      End
      Else
        WarnMsg('type element attendu');

      ElemTIdx := TypeResolve(ElemTName);
      If ElemTIdx = TY_UNKNOWN Then
      Begin
        WarnMsg('type element inconnu: ' + ElemTName);
        ElemTIdx := TY_IDX_INTEGER;
      End;
      ElemSz := TypeSizeof(ElemTIdx);

      ArrCount := ArrHi - ArrLo + 1;
      If ArrCount < 1 Then ArrCount := 1;
      ArrSize := ArrCount * ElemSz;

      { Creer entree TypeTab pour ce type array }
      NewArrTIdx := TY_IDX_INTEGER;
      If TypeCount < MAX_TYPE Then
      Begin
        NewArrTIdx := TypeCount;
        Inc(TypeCount);
        TypeTab[NewArrTIdx].Kind        := TKP_ARRAY;
        TypeTab[NewArrTIdx].Size        := ArrSize;
        TypeTab[NewArrTIdx].BaseTypeIdx := ElemTIdx;
        TypeTab[NewArrTIdx].Lo          := ArrLo;
        TypeTab[NewArrTIdx].Hi          := ArrHi;
        TypeTab[NewArrTIdx].FieldCount  := 0;
        TypeTab[NewArrTIdx].EnumCount   := 0;
      End
      Else
        WarnMsg('nombre maximal de types atteint');

      { Enregistrer chaque variable tableau }
      For I := 0 To NCount - 1 Do
      Begin
        Idx := SymAdd(Names[I], SC_VAR, NewArrTIdx);
        If Idx >= 0 Then
        Begin
          If CurScopeLevel = 0 Then
          Begin
            { Tableau global }
            SymTab[Idx].MangledName := PSP_ARR_PFX +
              StrUpperCase(Names[I]);
            DIdx := DataAddArray(
              SymTab[Idx].MangledName, ArrCount, ElemSz);
            SymTab[Idx].DataIdx := DIdx;
            SymTab[Idx].IsLocal := False;
            If Opts.DebugMode Then
              WriteLn('  VAR_ARRAY_GLOBAL: ', Names[I],
                      ' [', ArrLo, '..', ArrHi, '] of ',
                      ElemTName, ' -> ',
                      SymTab[Idx].MangledName);
          End
          Else
          Begin
            { Tableau local : allouer sur la pile }
            Dec(CurFrameOffset, ArrSize);
            SymTab[Idx].Offset  := CurFrameOffset;
            SymTab[Idx].IsLocal := True;
            If Opts.DebugMode Then
              WriteLn('  VAR_ARRAY_LOCAL: ', Names[I],
                      ' [', ArrLo, '..', ArrHi, '] of ',
                      ElemTName, ' -> ',
                      EBPOfs(CurFrameOffset));
          End;
        End;
      End;

      { Point-virgule }
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
        TplNextToken;
      Continue;
    End;

    { Lire le nom de type }
    TName := '';
    If (CurToken.Kind = TK_KEYWORD) Or (CurToken.Kind = TK_IDENT) Then
    Begin
      TName := CurToken.Val;
      TplNextToken;
    End
    Else
      WarnMsg('nom de type attendu');

    { Resoudre le type }
    TIdx := TypeResolve(TName);
    If TIdx = TY_UNKNOWN Then
    Begin
      WarnMsg('type inconnu: ' + TName);
      TIdx := TY_IDX_INTEGER;  { defaut }
    End;

    { Enregistrer chaque variable }
    For I := 0 To NCount - 1 Do
    Begin
      If CurScopeLevel = 0 Then
        Idx := DeclAllocGlobal(Names[I], TIdx)
      Else
        Idx := DeclAllocLocal(Names[I], TIdx);
    End;

    { Point-virgule }
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
      TplNextToken;
  End;
End;

{ ---- ParseAssignment : analyser une affectation --------------- }
{ Syntaxe : variable := expression ;                               }
{ Gere : retour de fonction, variable locale/globale, param var.   }
Procedure ParseAssignment(Const VarName : TString);
Var
  SIdx : Integer;
  Ev   : TExprVal;
Begin
  { Affectation a la valeur de retour : FuncName := expr }
  If (CurFuncName <> '') And
     ((StrLowerCase(VarName) = CurFuncName) Or
      (StrLowerCase(VarName) = 'result')) Then
  Begin
    { Consommer := }
    If (CurToken.Kind = TK_OP) And (CurToken.Val = ':=') Then
      TplNextToken
    Else
    Begin
      WarnMsg(''':='' attendu pour l''affectation');
      Exit;
    End;

    EmitComment('assign retval ' + VarName);
    ParseExpr(Ev);
    ExprFlushToEAX(Ev);
    EmitInstrAB('MOV',
      'DWORD PTR ' + EBPOfs(CurFuncRetOfs), 'EAX');
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
      TplNextToken;
    Exit;
  End;

  { Rechercher la variable }
  SIdx := SymFind(VarName);
  If SIdx < 0 Then
  Begin
    WarnMsg('variable non declaree: ' + VarName);
    { Sauter jusqu au ; }
    While (CurToken.Kind <> TK_EOF) And
          Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';')) Do
      TplNextToken;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
      TplNextToken;
    Exit;
  End;

  { Verifier que c est bien une variable/param }
  If Not (SymTab[SIdx].Cat In [SC_VAR, SC_PARAM, SC_VARPARAM,
                                 SC_TYPED_CONST]) Then
  Begin
    WarnMsg('cible d''affectation invalide: ' + VarName);
  End;

  { Consommer := }
  If (CurToken.Kind = TK_OP) And (CurToken.Val = ':=') Then
    TplNextToken
  Else
  Begin
    WarnMsg(''':='' attendu pour l''affectation');
    Exit;
  End;

  EmitComment('assign ' + VarName);

  { Evaluer l expression }
  ParseExpr(Ev);

  { Verification de compatibilite de type }
  If (SymTab[SIdx].TypeIdx <> TY_UNKNOWN) And
     (Ev.TypeIdx <> TY_UNKNOWN) Then
  Begin
    If Not TypeCompatible(SymTab[SIdx].TypeIdx, Ev.TypeIdx) Then
      ErrorMsg('type incompatible dans l''affectation de ' + VarName);
  End;

  { Materialiser la valeur dans EAX }
  ExprFlushToEAX(Ev);

  { Stocker EAX dans la cible }
  ExprStore(SIdx);

  { Point-virgule }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
    TplNextToken;
End;

{ ============================================================
  TODO 10 - EXPRESSIONS PRIMAIRES [IMPLEMENTE]
  ============================================================ }
{ La majorite des fonctions de ce TODO est implementee dans les
  sections TODO 04 (ParsePrimary, ParseCallArgs, ParseUnary,
  ExprMakeImm, ExprFlushToEAX avec litteraux, identificateurs,
  fonctions predefinies, acces tableaux, acces champs record,
  appels de fonctions, expressions parenthesees) et
  TODO 09 (ExprAddrOf, ExprStore, ExprLoad pour l acces aux
  variables locales, globales et parametres var).
  Ci-dessous : EmitPrintEAX, EmitHtmlFragment, EmitExprInline
  pour l emission PSP (fragments HTML et expressions en ligne). }

{ ---- EmitPrintEAX : emettre le code pour afficher EAX ------- }
{ Selon le type, emet le code pour convertir et afficher la      }
{ valeur dans EAX via les routines runtime Win32.                }
{   string  -> MOV ESI, EAX ; CALL _PSPRT_PRINTSTR              }
{   char    -> stocker dans CHRBUF ; CALL _PSPRT_PRINTSTR        }
{   boolean -> CMP + JE vers FALSE_S / TRUE_S ; PRINTSTR         }
{   integer -> CALL _PSPRT_NUMTOSTR ; PRINTSTR depuis NUMBUF    }
Procedure EmitPrintEAX(TypeIdx : Integer);
Var
  LblFalse, LblDone : TString;
Begin
  If TypeIdx = TY_IDX_STRING Then
  Begin
    { EAX = pointeur ASCIIZ -> imprimer directement }
    EmitInstrAB('MOV', 'ESI', 'EAX');
    EmitCall(PSP_RT_PFX + 'PRINTSTR');
  End
  Else If TypeIdx = TY_IDX_CHAR Then
  Begin
    { Stocker le caractere dans CHRBUF et imprimer }
    EmitInstrAB('MOV',
      'BYTE PTR [' + PSP_RT_PFX + 'CHRBUF]', 'AL');
    EmitInstrAB('MOV', 'ESI',
      'OFFSET ' + PSP_RT_PFX + 'CHRBUF');
    EmitCall(PSP_RT_PFX + 'PRINTSTR');
  End
  Else If TypeIdx = TY_IDX_BOOLEAN Then
  Begin
    { EAX = 0 -> FALSE, sinon -> TRUE }
    LblFalse := LabelGen;
    LblDone  := LabelGen;
    EmitInstrAB('CMP', 'EAX', '0');
    EmitInstrA('JE', LblFalse);
    EmitInstrAB('MOV', 'ESI',
      'OFFSET ' + PSP_RT_PFX + 'TRUE_S');
    EmitInstrA('JMP', LblDone);
    EmitLabel(LblFalse);
    EmitInstrAB('MOV', 'ESI',
      'OFFSET ' + PSP_RT_PFX + 'FALSE_S');
    EmitLabel(LblDone);
    EmitCall(PSP_RT_PFX + 'PRINTSTR');
  End
  Else
  Begin
    { Integer/Word/Byte/Real -> convertir en chaine + afficher }
    EmitCall(PSP_RT_PFX + 'NUMTOSTR');
    EmitInstrAB('MOV', 'ESI',
      'OFFSET ' + PSP_RT_PFX + 'NUMBUF');
    EmitCall(PSP_RT_PFX + 'PRINTSTR');
  End;
End;

{ ---- EmitHtmlFragment : emettre un fragment HTML literal ------ }
{ Stocke le texte en DATA sous _PSPK_HTML_N via DataAddHtml et    }
{ emet le code pour l afficher via _PSPRT_PRINTSTR.               }
Procedure EmitHtmlFragment(Const Html : TString);
Var
  Lbl : TString;
Begin
  If Length(Html) = 0 Then Exit;
  Lbl := DataAddHtml(Html);
  If Length(Lbl) = 0 Then Exit;
  EmitComment('html fragment');
  EmitInstrAB('MOV', 'ESI', 'OFFSET ' + Lbl);
  EmitCall(PSP_RT_PFX + 'PRINTSTR');
End;

{ ---- EmitExprInline : emettre une expression <%= expr %> ----- }
{ Evalue l expression, materialise dans EAX, imprime selon type.  }
{ CurToken doit etre sur le premier token de l expression.       }
{ Consomme jusqu au PSP_CLOSE (%>).                              }
Procedure EmitExprInline;
Var
  Ev : TExprVal;
Begin
  EmitComment('expr inline');
  ParseExpr(Ev);
  ExprFlushToEAX(Ev);
  EmitPrintEAX(Ev.TypeIdx);
  { Consommer le %> (PSP_CLOSE) s il est present }
  If CurToken.Kind = TK_PSP_CLOSE Then
    TplNextToken;
End;

{ ============================================================
  TODO 11 - EXPRESSIONS BINAIRES [IMPLEMENTE]
  ============================================================ }
{ La totalite de ce TODO est implementee dans la section
  TODO 04 (ParseExprPrec, OpPrec, ParseUnary, ParseExpr).
  ParseExprPrec est un parseur de Pratt en montee de precedence
  (4 niveaux Pascal) gerant :
  - Arithmetique entiere 32 bits : ADD/SUB EAX,EBX,
    IMUL EBX, CDQ+IDIV EBX pour *, div, /
  - MOD : IDIV -> resultat dans EDX (reste)
  - Comparaisons : CMP EAX,EBX + MOV EAX,0 + Jcc + INC EAX
  - Comparaison chaines : MOV ESI,EAX / MOV EDI,EBX /
    CALL _PSPRT_STRCMP / CMP EAX,0 + Jcc
  - Concatenation chaines : + sur String ->
    MOV ESI,EAX / MOV EDI,EBX / CALL _PSPRT_CONCAT
  - Logique/bits : AND/OR/XOR EAX,EBX
  - Decalages : MOV CL,BL / SHL EAX,CL et SHR EAX,CL
  - NOT (dans ParseUnary) : XOR EAX,1 (booleen) ou NOT EAX (bits)
  - Repli de constantes (constant folding) pour operandes immediats
  - Protection division par zero : CMP EBX,0 / JE _PSPRT_PANIC_DIV0
  - IN : stub avec avertissement (ensembles non supportes) }

{ ============================================================
  TODO 12 - ENTREES/SORTIES (Write/WriteLn) [IMPLEMENTE]
  ============================================================ }
{ La sortie se fait via l API Win32 WriteFile :
  GetStdHandle(STD_OUTPUT_HANDLE) -> _PSPRT_HSTDOUT
  WriteFile(hStdOut, ptr, len, &written, NULL)
  Les routines runtime _PSPRT_PRINTSTR / _PSPRT_NUMTOSTR /
  _PSPRT_CHR sont deja emises dans EmitFooter (TODO 07).
  EmitPrintEAX (TODO 10) gere l affichage selon le type. }

{ ---- ParseWriteStmt : analyser Write ou WriteLn -------------- }
{ Le mot-cle write/writeln a deja ete consomme.                  }
{ CurToken est sur ( si arguments, ou ; si WriteLn sans args.    }
Procedure ParseWriteStmt(IsWriteLn : Boolean);
Var
  Ev      : TExprVal;
  WidthEv : TExprVal;
Begin
  If IsWriteLn Then
    EmitComment('writeln')
  Else
    EmitComment('write');

  { Gerer WriteLn sans arguments -> juste CR+LF }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
  Begin
    If IsWriteLn Then
    Begin
      EmitInstrAB('MOV', 'ESI', 'OFFSET ' + PSP_RT_PFX + 'CRLF');
      EmitCall(PSP_RT_PFX + 'PRINTSTR');
    End;
    TplNextToken;
    Exit;
  End;

  { Consommer ( }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
    TplNextToken
  Else
  Begin
    { WriteLn sans parentheses -> CR+LF }
    If IsWriteLn Then
    Begin
      EmitInstrAB('MOV', 'ESI', 'OFFSET ' + PSP_RT_PFX + 'CRLF');
      EmitCall(PSP_RT_PFX + 'PRINTSTR');
    End;
    Exit;
  End;

  { Boucle sur les arguments }
  While (CurToken.Kind <> TK_EOF) And
        Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')')) Do
  Begin
    { Evaluer l expression argument }
    ParseExpr(Ev);

    { Detecter formatage Write(val:width) }
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ':') Then
    Begin
      TplNextToken;
      ParseExpr(WidthEv);
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ':') Then
      Begin
        TplNextToken;
        ParseExpr(WidthEv);
        WarnMsg('formatage flottant :w:d non supporte, ignore');
      End;
    End;

    { Materialiser et afficher }
    ExprFlushToEAX(Ev);
    EmitPrintEAX(Ev.TypeIdx);

    { Virgule entre arguments }
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
      TplNextToken;
  End;

  { Consommer ) }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
    TplNextToken;

  { WriteLn : ajouter CR+LF }
  If IsWriteLn Then
  Begin
    EmitInstrAB('MOV', 'ESI', 'OFFSET ' + PSP_RT_PFX + 'CRLF');
    EmitCall(PSP_RT_PFX + 'PRINTSTR');
  End;

  { Point-virgule }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
    TplNextToken;
End;

{ ============================================================
  TODO 13 - IF / CASE / BLOCS BEGIN..END [IMPLEMENTE]
  ============================================================ }
{ ParseBlock : BEGIN stmt [; stmt] END
  ParseIfStmt : IF cond THEN stmt [ELSE stmt]
    Emission TEST EAX,EAX / JZ pour condition fausse
    Labels : _PSPL_N (ELSE et ENDIF)
    Gestion du dangling else (attachement au if le plus proche)
  ParseCaseStmt : CASE expr OF val: stmt; [val: stmt;] [ELSE stmt] END
    Valeurs simples : CMP EAX,val / JE label_branche
    Intervalles : val1..val2 -> CMP EAX,val1 / JL skip /
      CMP EAX,val2 / JG skip -> JMP branche
    Valeurs multiples : val1, val2, val3 : stmt
    Labels : _PSPL_N (CASE et CEND)
  ParseStatement : dispatcheur principal pour tous les types
    d instructions (blocs, if, case, boucles, affectations,
    declarations, appels de procedures, E/S, etc.). }

{ ---- ParseBlock : analyser un bloc BEGIN...END --------------- }
Procedure ParseBlock;
Begin
  { Consommer begin }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'begin') Then
    TplNextToken
  Else
  Begin
    WarnMsg('''begin'' attendu');
    Exit;
  End;

  { Boucle : instructions separees par ; }
  While (CurToken.Kind <> TK_EOF) And
        Not ((CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'end')) Do
  Begin
    ParseStatement;
    { Consommer les ; separateurs }
    While (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Do
      TplNextToken;
  End;

  { Consommer end }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'end') Then
    TplNextToken
  Else
    WarnMsg('''end'' attendu pour fermer le bloc begin');
End;

{ ---- ParseIfStmt : analyser IF cond THEN stmt [ELSE stmt] --- }
Procedure ParseIfStmt;
Var
  Ev          : TExprVal;
  LblElse     : TString;
  LblEndIf    : TString;
  HasElsePart : Boolean;
Begin
  EmitComment('if');

  { Consommer if }
  TplNextToken;

  { Evaluer la condition }
  ParseExpr(Ev);
  ExprFlushToEAX(Ev);

  { Generer labels }
  LblElse  := LabelGen;
  LblEndIf := LabelGen;

  { TEST EAX,EAX / JZ lbl_else }
  EmitInstrAB('TEST', 'EAX', 'EAX');
  EmitInstrA('JZ', LblElse);

  { Consommer then }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'then') Then
    TplNextToken
  Else
    WarnMsg('''then'' attendu apres condition if');

  { Compiler le bloc then }
  ParseStatement;

  { Consommer le ; optionnel apres le stmt du then }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
    TplNextToken;

  { Verifier si else suit }
  HasElsePart := (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'else');

  If HasElsePart Then
  Begin
    { JMP endif pour sauter le bloc else }
    EmitInstrA('JMP', LblEndIf);
    { Label else }
    EmitLabel(LblElse);

    { Consommer else }
    TplNextToken;

    { Compiler le bloc else }
    ParseStatement;

    { Consommer le ; optionnel apres le stmt du else }
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
      TplNextToken;

    { Label endif }
    EmitLabel(LblEndIf);
  End
  Else
  Begin
    { Pas de else : label else = fin }
    EmitLabel(LblElse);
  End;
End;

{ ---- ParseCaseStmt : analyser CASE expr OF ... END ----------- }
Procedure ParseCaseStmt;
Var
  Ev       : TExprVal;
  CaseEv   : TExprVal;
  LblEnd   : TString;
  LblNext  : TString;
  LblHit   : TString;
  RangeHi  : LongInt;
  RangeLo  : LongInt;
Begin
  EmitComment('case');

  { Consommer case }
  TplNextToken;

  { Evaluer l expression switch }
  ParseExpr(Ev);
  ExprFlushToEAX(Ev);
  EmitInstrA('PUSH', 'EAX');  { sauvegarder la valeur sur la pile }

  { Consommer of }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'of') Then
    TplNextToken
  Else
    WarnMsg('''of'' attendu apres expression case');

  LblEnd := LabelGen;

  { Boucle sur les branches }
  While (CurToken.Kind <> TK_EOF) And
        Not ((CurToken.Kind = TK_KEYWORD) And
             ((CurToken.Val = 'end') Or (CurToken.Val = 'else'))) Do
  Begin
    LblNext := LabelGen;
    LblHit  := LabelGen;

    { Lire les valeurs de la branche (separees par virgule) }
    While (CurToken.Kind <> TK_EOF) And
          Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ':')) Do
    Begin
      { Recuperer la valeur de la branche }
      ParseExpr(CaseEv);

      { Restaurer la valeur switch dans EAX }
      EmitInstrAB('MOV', 'EAX', 'DWORD PTR [ESP]');

      { Detecter plage val1..val2 }
      If (CurToken.Kind = TK_OP) And (CurToken.Val = '..') Then
      Begin
        { Plage : CaseEv.ImmVal est la borne basse }
        If CaseEv.Kind <> EK_IMM Then
          WarnMsg('borne basse de case doit etre une constante');
        RangeLo := CaseEv.ImmVal;
        TplNextToken;  { consommer .. }
        RangeHi := 0;
        If CurToken.Kind = TK_INTEGER Then
        Begin
          RangeHi := CurToken.IntVal;
          TplNextToken;
        End
        Else
        Begin
          { Evaluer la borne haute }
          ParseExpr(CaseEv);
          If CaseEv.Kind <> EK_IMM Then
            WarnMsg('borne haute de case doit etre une constante');
          RangeHi := CaseEv.ImmVal;
        End;
        { CMP EAX, lo / JL next }
        EmitInstrAB('CMP', 'EAX', IntToStr(RangeLo));
        EmitInstrA('JL', LblNext);
        { CMP EAX, hi / JG next -> JLE hit }
        EmitInstrAB('CMP', 'EAX', IntToStr(RangeHi));
        EmitInstrA('JLE', LblHit);
        { Si pas dans la plage, aller a next }
        EmitInstrA('JMP', LblNext);
      End
      Else
      Begin
        { Valeur simple : CMP EAX, val / JE hit }
        If CaseEv.Kind = EK_IMM Then
          EmitInstrAB('CMP', 'EAX', IntToStr(CaseEv.ImmVal))
        Else
        Begin
          ExprFlushToEAX(CaseEv);
          EmitInstrAB('MOV', 'EBX', 'EAX');
          EmitInstrAB('MOV', 'EAX', 'DWORD PTR [ESP]');
          EmitInstrAB('CMP', 'EAX', 'EBX');
        End;
        EmitInstrA('JE', LblHit);
      End;

      { Virgule : autre valeur pour la meme branche }
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
        TplNextToken
      Else
        Break;
    End;

    { Aucun match : sauter a la branche suivante }
    EmitInstrA('JMP', LblNext);

    { Label hit : on arrive ici si un match est trouve }
    EmitLabel(LblHit);

    { Consommer le : }
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ':') Then
      TplNextToken;

    { Compiler l instruction de la branche }
    ParseStatement;

    { Consommer le ; optionnel }
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
      TplNextToken;

    { Sauter a la fin du case }
    EmitInstrA('JMP', LblEnd);

    { Label next : prochaine branche }
    EmitLabel(LblNext);
  End;

  { Branche else (default) }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'else') Then
  Begin
    TplNextToken;
    EmitComment('case else');
    { Boucle : instructions jusqu a end }
    While (CurToken.Kind <> TK_EOF) And
          Not ((CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'end')) Do
    Begin
      ParseStatement;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
        TplNextToken;
    End;
  End;

  { Label fin du case }
  EmitLabel(LblEnd);

  { Depiler la valeur switch }
  EmitInstrA('POP', 'EAX');

  { Consommer end }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'end') Then
    TplNextToken
  Else
    WarnMsg('''end'' attendu pour fermer le case');

  { Consommer le ; optionnel }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
    TplNextToken;
End;

{ ---- ParseStatement : dispatcheur principal d instructions --- }
{ Determine le type de l instruction courante et appelle le      }
{ parseur specialise correspondant.                               }
Procedure ParseStatement;
Var
  SavedName : TString;
  SIdx      : Integer;
  HaltEv    : TExprVal;
  ArrTIdx   : Integer;
  ArrLo     : LongInt;
  ElemSz    : Integer;
  IdxExpr   : TExprVal;
  ValExpr   : TExprVal;
  RecTIdx   : Integer;
  FldIdx    : Integer;
  FldTIdx   : Integer;
  FldSz     : Integer;
  FI        : Integer;
  WIdx      : Integer;
  WI        : Integer;
Begin
  { Rien a faire si EOF }
  If CurToken.Kind = TK_EOF Then Exit;

  { Emettre le label MAINBODY si pas encore fait }
  If (Not MainBodyEmitted) And (CurScopeLevel = 0) Then
  Begin
    EmitLabel(PSP_LBL_PFX + 'MAINBODY');
    MainBodyEmitted := True;
  End;

  { Fragment HTML }
  If CurToken.Kind = TK_HTML Then
  Begin
    EmitHtmlFragment(CurToken.Val);
    TplNextToken;
    Exit;
  End;

  { Expression inline <%= ... %> }
  If CurToken.Kind = TK_PSP_EXPR_OPEN Then
  Begin
    TplNextToken;
    EmitExprInline;
    Exit;
  End;

  { Directive PSP <% ... %> }
  If CurToken.Kind = TK_PSP_OPEN Then
  Begin
    TplNextToken;
    Exit;
  End;
  If CurToken.Kind = TK_PSP_CLOSE Then
  Begin
    TplNextToken;
    Exit;
  End;

  { Bloc begin ... end }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'begin') Then
  Begin
    ParseBlock;
    Exit;
  End;

  { if ... then ... [else ...] }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'if') Then
  Begin
    ParseIfStmt;
    Exit;
  End;

  { case ... of ... end }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'case') Then
  Begin
    ParseCaseStmt;
    Exit;
  End;

  { for ... to|downto ... do }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'for') Then
  Begin
    ParseForStmt;
    Exit;
  End;

  { while ... do ... }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'while') Then
  Begin
    ParseWhileStmt;
    Exit;
  End;

  { repeat ... until ... }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'repeat') Then
  Begin
    ParseRepeatStmt;
    Exit;
  End;

  { break }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'break') Then
  Begin
    TplNextToken;
    If LoopTop < 0 Then
      WarnMsg('''break'' en dehors d''une boucle')
    Else
      EmitInstrA('JMP', LoopBreakLbl[LoopTop]);
    Exit;
  End;

  { continue }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'continue') Then
  Begin
    TplNextToken;
    If LoopTop < 0 Then
      WarnMsg('''continue'' en dehors d''une boucle')
    Else
      EmitInstrA('JMP', LoopContLbl[LoopTop]);
    Exit;
  End;

  { Write / WriteLn }
  If (CurToken.Kind = TK_IDENT) And
     (StrLowerCase(CurToken.Val) = 'writeln') Then
  Begin
    TplNextToken;
    ParseWriteStmt(True);
    Exit;
  End;
  If (CurToken.Kind = TK_IDENT) And
     (StrLowerCase(CurToken.Val) = 'write') Then
  Begin
    TplNextToken;
    ParseWriteStmt(False);
    Exit;
  End;

  { var declarations }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'var') Then
  Begin
    TplNextToken;
    ParseVarDecl;
    Exit;
  End;

  { const declarations }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'const') Then
  Begin
    TplNextToken;
    ParseConstDecl;
    Exit;
  End;

  { type declarations }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'type') Then
  Begin
    TplNextToken;
    ParseTypeDecl;
    Exit;
  End;

  { Inc / Dec }
  If (CurToken.Kind = TK_IDENT) And
     (StrLowerCase(CurToken.Val) = 'inc') Then
  Begin
    TplNextToken;
    ParseIncDecStmt(True);
    Exit;
  End;
  If (CurToken.Kind = TK_IDENT) And
     (StrLowerCase(CurToken.Val) = 'dec') Then
  Begin
    TplNextToken;
    ParseIncDecStmt(False);
    Exit;
  End;

  { function / procedure declarations }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'function') Then
  Begin
    ParseFuncDecl;
    Exit;
  End;
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'procedure') Then
  Begin
    ParseProcDecl;
    Exit;
  End;

  { exit }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'exit') Then
  Begin
    TplNextToken;
    If CurRetLabel <> '' Then
      EmitInstrA('JMP', CurRetLabel)
    Else
      EmitComment('exit (pas dans une fonction)');
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
      TplNextToken;
    Exit;
  End;

  { halt / halt(code) }
  If (CurToken.Kind = TK_IDENT) And
     (StrLowerCase(CurToken.Val) = 'halt') Then
  Begin
    TplNextToken;
    EmitComment('halt');
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
    Begin
      TplNextToken;
      { Evaluer le code de sortie }
      ParseExpr(HaltEv);
      ExprFlushToEAX(HaltEv);
      EmitInstrA('PUSH', 'EAX');
      EmitInstrA('CALL', '_ExitProcess@4');
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
        TplNextToken;
    End
    Else
    Begin
      EmitInstrA('PUSH', '0');
      EmitInstrA('CALL', '_ExitProcess@4');
    End;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
      TplNextToken;
    Exit;
  End;

  { with RecVar do }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'with') Then
  Begin
    ParseWithStmt;
    Exit;
  End;

  { try...except...finally }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'try') Then
  Begin
    ParseTryExcept;
    Exit;
  End;

  { Identificateur : affectation ou appel de procedure }
  If CurToken.Kind = TK_IDENT Then
  Begin
    SavedName := CurToken.Val;
    TplNextToken;

    { Affectation : ident := expr }
    { Verifier d abord si c est un champ du with-stack }
    If (CurToken.Kind = TK_OP) And (CurToken.Val = ':=') Then
    Begin
      WIdx := -1;
      If WithTop >= 0 Then
      Begin
        For WI := WithTop DownTo 0 Do
        Begin
          RecTIdx := SymTab[WithSymIdx[WI]].TypeIdx;
          For FI := 0 To TypeTab[RecTIdx].FieldCount - 1 Do
            If StrLowerCase(TypeTab[RecTIdx].Fields[FI].Name) =
               StrLowerCase(SavedName) Then
            Begin
              WIdx := WI;
              FldIdx := FI;
              Break;
            End;
          If WIdx >= 0 Then Break;
        End;
      End;
      If WIdx >= 0 Then
      Begin
        RecTIdx := SymTab[WithSymIdx[WIdx]].TypeIdx;
        If SymTab[WithSymIdx[WIdx]].IsLocal Then
          EmitInstrAB('LEA', 'EBX',
            EBPOfs(SymTab[WithSymIdx[WIdx]].Offset))
        Else
          EmitInstrAB('MOV', 'EBX',
            'OFFSET ' + SymTab[WithSymIdx[WIdx]].MangledName);
        If TypeTab[RecTIdx].Fields[FldIdx].Offset > 0 Then
          EmitInstrAB('ADD', 'EBX',
            IntToStr(TypeTab[RecTIdx].Fields[FldIdx].Offset));
        EmitInstrA('PUSH', 'EBX');
        FldTIdx := TypeTab[RecTIdx].Fields[FldIdx].TypeIdx;
        FldSz   := TypeSizeof(FldTIdx);
        TplNextToken;
        EmitComment('with-assign ' + SavedName);
        ParseExpr(ValExpr);
        ExprFlushToEAX(ValExpr);
        EmitInstrA('POP', 'EBX');
        If FldSz = 1 Then
          EmitInstrAB('MOV', 'BYTE PTR [EBX]', 'AL')
        Else
          EmitInstrAB('MOV', 'DWORD PTR [EBX]', 'EAX');
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
          TplNextToken;
        Exit;
      End;
      ParseAssignment(SavedName);
      Exit;
    End;

    { Affectation element de tableau : ident[index] := expr }
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '[') Then
    Begin
      SIdx := SymFind(SavedName);
      If (SIdx >= 0) And (SIdx < SymCount) And
         (SymTab[SIdx].TypeIdx >= 0) And
         (SymTab[SIdx].TypeIdx < TypeCount) And
         (TypeTab[SymTab[SIdx].TypeIdx].Kind = TKP_ARRAY) Then
      Begin
        ArrTIdx := SymTab[SIdx].TypeIdx;
        ArrLo   := TypeTab[ArrTIdx].Lo;
        ElemSz  := TypeSizeof(TypeTab[ArrTIdx].BaseTypeIdx);

        TplNextToken;

        ParseExpr(IdxExpr);
        ExprFlushToEAX(IdxExpr);

        EmitInstrA('PUSH', 'EAX');

        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ']') Then
          TplNextToken
        Else
          WarnMsg(''']'' attendu apres index de tableau');

        If (CurToken.Kind = TK_OP) And (CurToken.Val = ':=') Then
          TplNextToken
        Else
          WarnMsg(''':='' attendu apres arr[i]');

        EmitComment('assign ' + SavedName + '[]');

        ParseExpr(ValExpr);
        ExprFlushToEAX(ValExpr);

        EmitInstrA('POP', 'ECX');

        If ArrLo <> 0 Then
          EmitInstrAB('SUB', 'ECX', IntToStr(ArrLo));
        If ElemSz = 4 Then
          EmitInstrAB('SHL', 'ECX', '2')
        Else If ElemSz = 2 Then
          EmitInstrAB('SHL', 'ECX', '1')
        Else If ElemSz > 4 Then
        Begin
          EmitInstrA('PUSH', 'EAX');
          EmitInstrAB('MOV', 'EAX', 'ECX');
          EmitInstrAB('MOV', 'ECX', IntToStr(ElemSz));
          EmitInstrAB('IMUL', 'EAX', 'ECX');
          EmitInstrAB('MOV', 'ECX', 'EAX');
          EmitInstrA('POP', 'EAX');
        End;

        If SymTab[SIdx].IsLocal Then
          EmitInstrAB('LEA', 'EBX',
            EBPOfs(SymTab[SIdx].Offset))
        Else
          EmitInstrAB('MOV', 'EBX',
            'OFFSET ' + SymTab[SIdx].MangledName);

        EmitInstrAB('ADD', 'EBX', 'ECX');

        If ElemSz = 1 Then
          EmitInstrAB('MOV', 'BYTE PTR [EBX]', 'AL')
        Else If ElemSz = 2 Then
          EmitInstrAB('MOV', 'WORD PTR [EBX]', 'AX')
        Else
          EmitInstrAB('MOV', 'DWORD PTR [EBX]', 'EAX');

        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
          TplNextToken;
        Exit;
      End
      Else
      Begin
        WarnMsg('indexation sur un non-tableau: ' + SavedName);
        While (CurToken.Kind <> TK_EOF) And
              Not ((CurToken.Kind = TK_PUNCT) And
                   (CurToken.Val = ';')) Do
          TplNextToken;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
          TplNextToken;
        Exit;
      End;
    End;

    { Affectation champ record : ident.field := expr }
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '.') Then
    Begin
      SIdx := SymFind(SavedName);
      If (SIdx >= 0) And (SIdx < SymCount) And
         (SymTab[SIdx].TypeIdx >= 0) And
         (SymTab[SIdx].TypeIdx < TypeCount) And
         (TypeTab[SymTab[SIdx].TypeIdx].Kind = TKP_RECORD) Then
      Begin
        RecTIdx := SymTab[SIdx].TypeIdx;
        If SymTab[SIdx].IsLocal Then
          EmitInstrAB('LEA', 'EBX',
            EBPOfs(SymTab[SIdx].Offset))
        Else
          EmitInstrAB('MOV', 'EBX',
            'OFFSET ' + SymTab[SIdx].MangledName);
        FldTIdx := TY_IDX_INTEGER;
        FldSz   := 4;
        While (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '.') Do
        Begin
          TplNextToken;
          If CurToken.Kind = TK_IDENT Then
          Begin
            FldIdx := -1;
            For FI := 0 To TypeTab[RecTIdx].FieldCount - 1 Do
              If StrLowerCase(TypeTab[RecTIdx].Fields[FI].Name) =
                 StrLowerCase(CurToken.Val) Then
              Begin
                FldIdx := FI;
                Break;
              End;
            If FldIdx >= 0 Then
            Begin
              If TypeTab[RecTIdx].Fields[FldIdx].Offset > 0 Then
                EmitInstrAB('ADD', 'EBX',
                  IntToStr(TypeTab[RecTIdx].Fields[FldIdx].Offset));
              FldTIdx := TypeTab[RecTIdx].Fields[FldIdx].TypeIdx;
              FldSz   := TypeSizeof(FldTIdx);
              TplNextToken;
              If (FldTIdx >= 0) And (FldTIdx < TypeCount) And
                 (TypeTab[FldTIdx].Kind = TKP_RECORD) Then
                RecTIdx := FldTIdx;
            End
            Else
            Begin
              WarnMsg('champ inconnu: ' + CurToken.Val);
              TplNextToken;
              Break;
            End;
          End
          Else
          Begin
            WarnMsg('nom de champ attendu apres "."');
            Break;
          End;
        End;
        EmitInstrA('PUSH', 'EBX');
        If (CurToken.Kind = TK_OP) And (CurToken.Val = ':=') Then
          TplNextToken
        Else
          WarnMsg(''':='' attendu apres rec.field');
        EmitComment('assign ' + SavedName + '.field');
        ParseExpr(ValExpr);
        ExprFlushToEAX(ValExpr);
        EmitInstrA('POP', 'EBX');
        If FldSz = 1 Then
          EmitInstrAB('MOV', 'BYTE PTR [EBX]', 'AL')
        Else
          EmitInstrAB('MOV', 'DWORD PTR [EBX]', 'EAX');
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
          TplNextToken;
        Exit;
      End
      Else
      Begin
        WarnMsg('acces "." sur un non-record: ' + SavedName);
        While (CurToken.Kind <> TK_EOF) And
              Not ((CurToken.Kind = TK_PUNCT) And
                   (CurToken.Val = ';')) Do
          TplNextToken;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
          TplNextToken;
        Exit;
      End;
    End;

    { Appel de procedure : ident(...) ou ident sans args }
    SIdx := SymFind(SavedName);
    If SIdx >= 0 Then
    Begin
      If SymTab[SIdx].Cat In [SC_PROC, SC_FUNC] Then
      Begin
        EmitComment('call ' + SavedName);
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
          ParseCallArgs(SIdx);
        EmitCall(SymTab[SIdx].MangledName);
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
          TplNextToken;
        Exit;
      End;
    End;

    { Identificateur inconnu ou non-procedure : avertir et sauter }
    WarnMsg('instruction inconnue ou non implementee: ' + SavedName);
    While (CurToken.Kind <> TK_EOF) And
          Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';')) And
          Not ((CurToken.Kind = TK_KEYWORD) And
               ((CurToken.Val = 'end') Or (CurToken.Val = 'else'))) Do
      TplNextToken;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
      TplNextToken;
    Exit;
  End;

  { Point-virgule seul : instruction vide }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
  Begin
    TplNextToken;
    Exit;
  End;

  { Token inconnu : sauter pour eviter une boucle infinie }
  If CurToken.Kind <> TK_EOF Then
  Begin
    WarnMsg('token inattendu: ' + CurToken.Val);
    TplNextToken;
  End;
End;

{ ============================================================
  TODO 14 - BOUCLES : FOR / WHILE / REPEAT / BREAK / CONTINUE
            [IMPLEMENTE]
  ============================================================ }
{ LoopPush / LoopPop : pile de labels pour break/continue
  ParseForStmt : FOR id := lo TO|DOWNTO hi DO stmt
    Variable locale ou globale comme compteur
    TO : increment par INC / CMP EAX,hi / JG fin
    DOWNTO : decrement par DEC / CMP EAX,lo / JL fin
    Limite stockee dans .DATA (DataAddDWord)
  ParseWhileStmt : WHILE cond DO stmt
    Labels : test + fin
    Emission TEST EAX,EAX / JZ fin, JMP test
  ParseRepeatStmt : REPEAT stmts UNTIL cond
    Labels : debut + fin
    Emission TEST EAX,EAX / JZ debut
  BREAK : JMP vers label de fin de boucle englobante
  CONTINUE : JMP vers label de test/increment de boucle
    (deja geres dans ParseStatement) }

{ ---- LoopPush : empiler un contexte de boucle ---------------- }
Procedure LoopPush(Const LblBreak, LblCont : TString);
Begin
  Inc(LoopTop);
  If LoopTop >= MAX_LOOP_NEST Then
  Begin
    WarnMsg('trop de boucles imbriquees');
    Dec(LoopTop);
    Exit;
  End;
  LoopBreakLbl[LoopTop] := LblBreak;
  LoopContLbl[LoopTop]  := LblCont;
End;

{ ---- LoopPop : depiler un contexte de boucle ----------------- }
Procedure LoopPop;
Begin
  If LoopTop >= 0 Then
    Dec(LoopTop);
End;

{ ---- ParseForStmt : for v := expr1 to|downto expr2 do stmt --- }
{ CurToken est sur 'for'.                                        }
Procedure ParseForStmt;
Var
  VarName   : TString;
  Ev        : TExprVal;
  LimLabel  : TString;
  LblTest   : TString;
  LblEnd    : TString;
  LblCont   : TString;
  IsDownTo  : Boolean;
  SIdx      : Integer;
  VarRef    : TString;
Begin
  EmitComment('for');

  { Consommer for }
  TplNextToken;

  { Lire la variable de boucle }
  If CurToken.Kind <> TK_IDENT Then
  Begin
    WarnMsg('variable de boucle attendue apres ''for''');
    Exit;
  End;
  VarName := CurToken.Val;
  TplNextToken;

  { Consommer := }
  If (CurToken.Kind = TK_OP) And (CurToken.Val = ':=') Then
    TplNextToken
  Else
    WarnMsg(''':='' attendu apres variable de boucle');

  { Evaluer l expression de depart }
  ParseExpr(Ev);
  ExprFlushToEAX(Ev);

  { Chercher le symbole de la variable }
  SIdx := SymFind(VarName);
  If SIdx < 0 Then
  Begin
    WarnMsg('variable de boucle ''' + VarName + ''' non declaree');
    Exit;
  End;
  If SymTab[SIdx].IsLocal Then
    VarRef := 'DWORD PTR ' + EBPOfs(SymTab[SIdx].Offset)
  Else
    VarRef := 'DWORD PTR [' + SymTab[SIdx].MangledName + ']';

  { Stocker la valeur de depart }
  EmitInstrAB('MOV', VarRef, 'EAX');

  { Consommer to ou downto }
  IsDownTo := False;
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'to') Then
    TplNextToken
  Else If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'downto') Then
  Begin
    IsDownTo := True;
    TplNextToken;
  End
  Else
    WarnMsg('''to'' ou ''downto'' attendu');

  { Evaluer l expression limite et la stocker dans une variable data }
  ParseExpr(Ev);
  ExprFlushToEAX(Ev);
  LimLabel := LabelGen;
  EmitInstrAB('MOV', 'DWORD PTR [' + LimLabel + ']', 'EAX');

  { Generer les labels de boucle }
  LblTest := LabelGen;
  LblEnd  := LabelGen;
  LblCont := LabelGen;

  { Consommer do }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'do') Then
    TplNextToken
  Else
    WarnMsg('''do'' attendu apres expression limite');

  { Label de test }
  EmitLabel(LblTest);

  { Test : CMP var, limite }
  EmitInstrAB('MOV', 'EAX', VarRef);
  EmitInstrAB('CMP', 'EAX', 'DWORD PTR [' + LimLabel + ']');
  If IsDownTo Then
    EmitInstrA('JL', LblEnd)
  Else
    EmitInstrA('JG', LblEnd);

  { Empiler le contexte de boucle }
  LoopPush(LblEnd, LblCont);

  { Compiler le corps de la boucle }
  ParseStatement;

  { Consommer le ; optionnel }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
    TplNextToken;

  { Label continue (increment) }
  EmitLabel(LblCont);

  { Increment ou decrement }
  If IsDownTo Then
    EmitInstrA('DEC', VarRef)
  Else
    EmitInstrA('INC', VarRef);

  { Retour au test }
  EmitInstrA('JMP', LblTest);

  { Label fin }
  EmitLabel(LblEnd);

  { Depiler le contexte de boucle }
  LoopPop;

  { Ajouter la variable limite dans le segment de donnees }
  DataAddDWord(LimLabel, 0);
End;

{ ---- ParseWhileStmt : while expr do stmt --------------------- }
{ CurToken est sur 'while'.                                       }
Procedure ParseWhileStmt;
Var
  Ev      : TExprVal;
  LblTest : TString;
  LblEnd  : TString;
Begin
  EmitComment('while');

  { Consommer while }
  TplNextToken;

  { Generer les labels }
  LblTest := LabelGen;
  LblEnd  := LabelGen;

  { Label de test }
  EmitLabel(LblTest);

  { Evaluer la condition }
  ParseExpr(Ev);
  ExprFlushToEAX(Ev);

  { TEST EAX,EAX / JZ fin }
  EmitInstrAB('TEST', 'EAX', 'EAX');
  EmitInstrA('JZ', LblEnd);

  { Consommer do }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'do') Then
    TplNextToken
  Else
    WarnMsg('''do'' attendu apres condition while');

  { Empiler le contexte de boucle }
  LoopPush(LblEnd, LblTest);

  { Compiler le corps }
  ParseStatement;

  { Consommer le ; optionnel }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
    TplNextToken;

  { Retour au test }
  EmitInstrA('JMP', LblTest);

  { Label fin }
  EmitLabel(LblEnd);

  { Depiler le contexte de boucle }
  LoopPop;
End;

{ ---- ParseRepeatStmt : repeat stmts until expr --------------- }
{ CurToken est sur 'repeat'.                                     }
Procedure ParseRepeatStmt;
Var
  Ev     : TExprVal;
  LblBeg : TString;
  LblEnd : TString;
Begin
  EmitComment('repeat');

  { Consommer repeat }
  TplNextToken;

  { Generer les labels }
  LblBeg := LabelGen;
  LblEnd := LabelGen;

  { Label debut }
  EmitLabel(LblBeg);

  { Empiler le contexte de boucle }
  LoopPush(LblEnd, LblBeg);

  { Compiler les instructions jusqu a until }
  While (CurToken.Kind <> TK_EOF) And
        Not ((CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'until')) Do
  Begin
    ParseStatement;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
      TplNextToken;
  End;

  { Consommer until }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'until') Then
    TplNextToken
  Else
    WarnMsg('''until'' attendu pour fermer le repeat');

  { Evaluer la condition }
  ParseExpr(Ev);
  ExprFlushToEAX(Ev);

  { TEST EAX,EAX / JZ debut (si faux, on boucle) }
  EmitInstrAB('TEST', 'EAX', 'EAX');
  EmitInstrA('JZ', LblBeg);

  { Label fin }
  EmitLabel(LblEnd);

  { Depiler le contexte de boucle }
  LoopPop;
End;

(* ============================================================
   TODO 15 - TABLEAUX (ARRAY) [IMPLEMENTE]
   ============================================================
   Code reparti dans les fonctions existantes :
   - ParseVarDecl : declaration ARRAY[lo..hi] OF Type
     (type TKP_ARRAY, global via DataAddArray, local sur pile)
   - ParsePrimary : lecture element arr[i] avec calcul index 32 bits
     (SUB lo, SHL/IMUL elemsize, LEA/MOV base, MOV EAX,[EBX])
   - ParseStatement : ecriture element arr[i] := expr
     (PUSH index, parse value, POP ECX, calcul offset, MOV [EBX],EAX)
   - Length/Low/High/SizeOf : constantes evaluees a la compilation
     (Length = Hi - Lo + 1, Low = Lo, High = Hi,
      SizeOf = (Hi - Lo + 1) * sizeof element)
   - EmitDataSeg : emission DK_ARRAY (DB n DUP(0) / DD n DUP(0))
   - TypeTab : Kind=TKP_ARRAY, Lo, Hi, BaseTypeIdx, Size *)

{ ============================================================
  TODO 18 - PROCEDURES ET FONCTIONS [IMPLEMENTE]
  ============================================================ }
{ ParseParamList : parser une liste de parametres formels.
  Syntaxe : (a, b: Integer; var c: String; ...)
  Chaque parametre occupe un DWORD (4 octets) sur la pile.
  Retourne le nombre total d octets de parametres.
  Les parametres sont ajoutes a la table des symboles (SC_PARAM
  ou SC_VARPARAM) avec leur offset corrige [EBP+8+...].
  Convention Pascal : args empiles gauche a droite,
  premier param = [EBP+8+(ParamBytes-4)], dernier = [EBP+8].

  ParseFuncOrProc(IsFunc) : declaration complete de fonction/procedure.
  - Signature : nom, parametres, type de retour (fonctions)
  - FORWARD : declaration anticipee (corps differe)
  - Declarations locales (var, const, type, proc/func imbriquees)
  - Prologue : PUSH EBP / MOV EBP,ESP / SUB ESP,n / PUSH ESI,EDI
  - Corps : begin ... end (via ParseBlock)
  - Label de retour pour Exit (JMP vers epilogue)
  - Retour fonction : valeur en [EBP-4] chargee dans EAX
  - Epilogue : POP EDI,ESI / MOV ESP,EBP / POP EBP / RET n
  - PROC / ENDP directives MASM
  - Contexte sauvegarde/restaure (CurFrameOffset, CurFuncName...)

  ParseFuncDecl / ParseProcDecl : enveloppes appelant ParseFuncOrProc. }

{ ---- ParseParamList ------------------------------------------- }
Function ParseParamList : Integer;
Var
  Names      : Array[0..MAX_PARAM - 1] Of TString;
  IsVar      : Array[0..MAX_PARAM - 1] Of Boolean;
  NCount     : Integer;
  TName      : TString;
  TIdx       : Integer;
  ParamBytes : Integer;
  I, Idx     : Integer;
  Cat        : TSymCat;
Begin
  ParamBytes := 0;

  { Consommer ( }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
    TplNextToken
  Else
  Begin
    ParseParamList := 0;
    Exit;
  End;

  While (CurToken.Kind <> TK_EOF) And
        Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')')) Do
  Begin
    NCount := 0;

    { Detecter var }
    If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'var') Then
    Begin
      For I := 0 To MAX_PARAM - 1 Do
        IsVar[I] := True;
      TplNextToken;
    End
    Else
    Begin
      For I := 0 To MAX_PARAM - 1 Do
        IsVar[I] := False;
    End;

    { Collecter les noms de parametres }
    While (CurToken.Kind = TK_IDENT) Do
    Begin
      If NCount < MAX_PARAM Then
      Begin
        Names[NCount] := CurToken.Val;
        Inc(NCount);
      End;
      TplNextToken;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
        TplNextToken
      Else
        Break;
    End;

    { Deux-points + type }
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ':') Then
      TplNextToken
    Else
      WarnMsg(''':'' attendu dans liste de parametres');

    TName := '';
    If (CurToken.Kind = TK_KEYWORD) Or (CurToken.Kind = TK_IDENT) Then
    Begin
      TName := CurToken.Val;
      TplNextToken;
    End;

    TIdx := TypeResolve(TName);
    If TIdx = TY_UNKNOWN Then
    Begin
      WarnMsg('type de parametre inconnu: ' + TName);
      TIdx := TY_IDX_INTEGER;
    End;

    { Enregistrer les parametres dans la table des symboles }
    For I := 0 To NCount - 1 Do
    Begin
      If IsVar[I] Then
        Cat := SC_VARPARAM
      Else
        Cat := SC_PARAM;
      Idx := SymAdd(Names[I], Cat, TIdx);
      If Idx >= 0 Then
      Begin
        { Offset provisoire = rang en octets, sera corrige plus bas }
        SymTab[Idx].Offset  := ParamBytes;
        SymTab[Idx].IsLocal := True;
      End;
      Inc(ParamBytes, 4);  { chaque parametre = 1 DWORD sur la pile }
    End;

    { Point-virgule entre groupes de parametres }
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
      TplNextToken;
  End;

  { Consommer ) }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
    TplNextToken;

  { Corriger les offsets des parametres.
    Convention Pascal, args empiles gauche a droite, callee cleanup.
    Apres PUSH EBP / MOV EBP,ESP :
      [EBP+0] = saved EBP
      [EBP+4] = adresse de retour
      params a partir de [EBP+8]
    Premier param (rang 0) -> offset le plus haut
    Dernier param (rang PB-4) -> offset le plus bas [EBP+8] }
  For I := SymCount - 1 DownTo 0 Do
  Begin
    If (SymTab[I].ScopeLevel = CurScopeLevel) And
       (SymTab[I].Cat In [SC_PARAM, SC_VARPARAM]) Then
    Begin
      SymTab[I].Offset := 8 + (ParamBytes - 4 - SymTab[I].Offset);
      If Opts.DebugMode Then
        WriteLn('  PARAM: ', SymTab[I].Name, ' [EBP+',
                SymTab[I].Offset, ']');
    End;
  End;

  ParseParamList := ParamBytes;
End;

{ ---- ParseFuncOrProc ------------------------------------------ }
Procedure ParseFuncOrProc(IsFunc : Boolean);
Var
  FuncName     : TString;
  RetTypeName  : TString;
  RetTypeIdx   : Integer;
  FIdx         : Integer;
  ParamBytes   : Integer;
  FrameSize    : Integer;
  RetLabel     : TString;
  SaveFrame    : Integer;
  SaveFuncName : TString;
  SaveRetOfs   : Integer;
  SaveRetLabel : TString;
  SaveParamB   : Integer;
  Cat          : TSymCat;
  RetVarIdx    : Integer;
  VarMask      : LongInt;
  PCnt         : Integer;
  I            : Integer;
Begin
  { Consommer function/procedure }
  TplNextToken;

  { Nom de la fonction / procedure }
  If CurToken.Kind <> TK_IDENT Then
  Begin
    WarnMsg('nom de fonction/procedure attendu');
    Exit;
  End;
  FuncName := CurToken.Val;
  TplNextToken;

  { Categorie }
  If IsFunc Then
    Cat := SC_FUNC
  Else
    Cat := SC_PROC;

  { Type de retour par defaut }
  RetTypeIdx := TY_IDX_INTEGER;

  { Verifier si c est une redeclaration (forward resolue) }
  FIdx := SymFindInScope(FuncName, CurScopeLevel);
  If (FIdx >= 0) And SymTab[FIdx].IsForward Then
  Begin
    { Forward resolue : on reutilise le symbole }
    SymTab[FIdx].IsForward := False;
  End
  Else
  Begin
    { Nouvelle declaration }
    FIdx := SymAdd(FuncName, Cat, RetTypeIdx);
  End;

  { Entrer dans le scope de la fonction }
  SymEnterScope;
  Inc(CurNestLevel);
  If CurNestLevel > NEST_MAX Then
    WarnMsg('imbrication de fonctions trop profonde (>' +
            IntToStr(NEST_MAX) + ')');

  { Parser les parametres }
  ParamBytes := 0;
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
    ParamBytes := ParseParamList;

  { Construire le masque des parametres var }
  If FIdx >= 0 Then
  Begin
    VarMask := 0;
    PCnt    := 0;
    For I := 0 To SymCount - 1 Do
    Begin
      If (SymTab[I].ScopeLevel = CurScopeLevel) And
         (SymTab[I].ScopeId = CurScopeId) And
         (SymTab[I].Cat In [SC_PARAM, SC_VARPARAM]) Then
      Begin
        If (SymTab[I].Cat = SC_VARPARAM) And (PCnt < 31) Then
          VarMask := VarMask Or (LongInt(1) Shl PCnt);
        Inc(PCnt);
      End;
    End;
    SymTab[FIdx].ParamCnt     := PCnt;
    SymTab[FIdx].VarParamMask := VarMask;
    If Opts.DebugMode Then
      WriteLn('  FUNC_PARAMS: ', FuncName, ' cnt=', PCnt,
              ' varmask=', VarMask);
  End;

  { Type de retour pour les fonctions }
  If IsFunc Then
  Begin
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ':') Then
    Begin
      TplNextToken;
      RetTypeName := '';
      If (CurToken.Kind = TK_KEYWORD) Or
         (CurToken.Kind = TK_IDENT) Then
      Begin
        RetTypeName := CurToken.Val;
        TplNextToken;
      End;
      RetTypeIdx := TypeResolve(RetTypeName);
      If RetTypeIdx = TY_UNKNOWN Then
      Begin
        WarnMsg('type de retour inconnu: ' + RetTypeName);
        RetTypeIdx := TY_IDX_INTEGER;
      End;
    End;
    If FIdx >= 0 Then
      SymTab[FIdx].TypeIdx := RetTypeIdx;
  End
  Else
  Begin
    { Procedure : pas de valeur de retour }
    RetTypeIdx := TY_UNKNOWN;
    If FIdx >= 0 Then
      SymTab[FIdx].TypeIdx := TY_UNKNOWN;
  End;

  { Point-virgule apres la signature }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
    TplNextToken;

  { Verifier si forward }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'forward') Then
  Begin
    If FIdx >= 0 Then
      SymTab[FIdx].IsForward := True;
    TplNextToken;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
      TplNextToken;
    SymLeaveScope;
    Dec(CurNestLevel);
    Exit;
  End;

  { Sauvegarder le contexte du cadre parent }
  SaveFrame    := CurFrameOffset;
  SaveFuncName := CurFuncName;
  SaveRetOfs   := CurFuncRetOfs;
  SaveRetLabel := CurRetLabel;
  SaveParamB   := CurParamBytes;

  CurFrameOffset := 0;
  CurParamBytes  := ParamBytes;
  RetLabel       := LabelGen;
  CurRetLabel    := RetLabel;

  { Pour les fonctions : allouer une variable locale pour la valeur
    de retour. On la stocke en [EBP-4] (DWORD). }
  If IsFunc Then
  Begin
    Dec(CurFrameOffset, 4);
    CurFuncName   := StrLowerCase(FuncName);
    CurFuncRetOfs := CurFrameOffset;

    { Ajouter "result" comme alias de la valeur de retour }
    RetVarIdx := SymAdd('result', SC_VAR, RetTypeIdx);
    If RetVarIdx >= 0 Then
    Begin
      SymTab[RetVarIdx].Offset  := CurFuncRetOfs;
      SymTab[RetVarIdx].IsLocal := True;
    End;
  End
  Else
    CurFuncName := '';

  { Declarations locales const/var/type et proc/func imbriquees }
  While ((CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'const')) Or
        ((CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'var')) Or
        ((CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'type')) Or
        ((CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'function')) Or
        ((CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'procedure')) Do
  Begin
    If CurToken.Val = 'const' Then
    Begin
      TplNextToken;
      ParseConstDecl;
    End
    Else If CurToken.Val = 'var' Then
    Begin
      TplNextToken;
      ParseVarDecl;
      If HasPendingAssign Then
      Begin
        HasPendingAssign := False;
        ParseAssignment(PendingAssignName);
      End;
    End
    Else If CurToken.Val = 'type' Then
    Begin
      TplNextToken;
      ParseTypeDecl;
    End
    Else If CurToken.Val = 'function' Then
      ParseFuncDecl
    Else If CurToken.Val = 'procedure' Then
      ParseProcDecl;
  End;

  { Calculer la taille du cadre local }
  FrameSize := -CurFrameOffset;  { CurFrameOffset est negatif }

  { Emettre le code de la procedure }
  EmitBlankLine;
  EmitComment('--- ' + FuncName + ' ---');
  If FIdx >= 0 Then
    EmitRaw(SymTab[FIdx].MangledName + '   PROC')
  Else
    EmitRaw(PSP_FN_PFX + StrUpperCase(FuncName) + '   PROC');

  { Prologue }
  EmitProlog(FrameSize);

  { Initialiser la valeur de retour a 0 }
  If IsFunc Then
    EmitInstrAB('MOV', 'DWORD PTR ' + EBPOfs(CurFuncRetOfs), '0');

  { Corps : begin ... end }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'begin') Then
    ParseBlock
  Else
    WarnMsg('''begin'' attendu dans le corps de ' + FuncName);

  { Label de retour (pour Exit) }
  EmitLabel(RetLabel);

  { Charger la valeur de retour dans EAX (fonctions) }
  If IsFunc Then
    EmitInstrAB('MOV', 'EAX',
      'DWORD PTR ' + EBPOfs(CurFuncRetOfs));

  { Epilogue }
  EmitEpilog(ParamBytes);

  If FIdx >= 0 Then
    EmitRaw(SymTab[FIdx].MangledName + '   ENDP')
  Else
    EmitRaw(PSP_FN_PFX + StrUpperCase(FuncName) + '   ENDP');
  EmitBlankLine;

  { Consommer le ; final apres end }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
    TplNextToken;

  { Restaurer le contexte }
  SymLeaveScope;
  Dec(CurNestLevel);
  CurFrameOffset := SaveFrame;
  CurFuncName    := SaveFuncName;
  CurFuncRetOfs  := SaveRetOfs;
  CurRetLabel    := SaveRetLabel;
  CurParamBytes  := SaveParamB;
End;

{ ---- ParseFuncDecl / ParseProcDecl : enveloppes --------------- }
Procedure ParseFuncDecl;
Begin
  ParseFuncOrProc(True);
End;

Procedure ParseProcDecl;
Begin
  ParseFuncOrProc(False);
End;

{ --- Stubs Types/Enumerations (TODO 06 / 17) --- }
{ ParseTypeDecl : gere TYPE name = RECORD ... END (et aliases).
  Les enumerations seront ajoutees dans un TODO futur.            }
Procedure ParseTypeDecl;
Var
  TName    : TString;
  NewTIdx  : Integer;
  BaseTIdx : Integer;
  BaseStr  : TString;
  Idx      : Integer;
  OrdVal   : LongInt;
  EnName   : TString;
  LoVal    : LongInt;
  Ev       : TExprVal;
Begin
  While (CurToken.Kind <> TK_EOF) And
        (CurToken.Kind = TK_IDENT) Do
  Begin
    TName := CurToken.Val;
    TplNextToken;

    If (CurToken.Kind = TK_OP) And (CurToken.Val = '=') Then
      TplNextToken
    Else
    Begin
      WarnMsg('''='' attendu apres nom de type');
      Break;
    End;

    { RECORD ... END }
    If (CurToken.Kind = TK_KEYWORD) And
       (StrLowerCase(CurToken.Val) = 'record') Then
    Begin
      TplNextToken;
      NewTIdx := TypeCount;
      Inc(TypeCount);
      TypeTab[NewTIdx].Kind        := TKP_RECORD;
      TypeTab[NewTIdx].Size        := 0;
      TypeTab[NewTIdx].BaseTypeIdx := TY_IDX_INTEGER;
      TypeTab[NewTIdx].Lo          := 0;
      TypeTab[NewTIdx].Hi          := 0;
      TypeTab[NewTIdx].FieldCount  := 0;
      TypeTab[NewTIdx].EnumCount   := 0;

      While (CurToken.Kind <> TK_EOF) And
            Not ((CurToken.Kind = TK_KEYWORD) And
                 (CurToken.Val = 'end')) Do
      Begin
        If (CurToken.Kind = TK_IDENT) Or
           (CurToken.Kind = TK_KEYWORD) Then
        Begin
          BaseStr := CurToken.Val;
          TplNextToken;

          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ':') Then
            TplNextToken
          Else
            WarnMsg(''':'' attendu apres nom de champ');

          BaseTIdx := TY_IDX_INTEGER;
          If (CurToken.Kind = TK_KEYWORD) Or
             (CurToken.Kind = TK_IDENT) Then
          Begin
            BaseTIdx := TypeResolve(CurToken.Val);
            If BaseTIdx = TY_UNKNOWN Then
            Begin
              WarnMsg('type de champ inconnu: ' + CurToken.Val);
              BaseTIdx := TY_IDX_INTEGER;
            End;
            TplNextToken;
          End;

          If TypeTab[NewTIdx].FieldCount < MAX_FIELD Then
          Begin
            TypeTab[NewTIdx].Fields[
              TypeTab[NewTIdx].FieldCount].Name :=
                StrLowerCase(BaseStr);
            TypeTab[NewTIdx].Fields[
              TypeTab[NewTIdx].FieldCount].TypeIdx := BaseTIdx;
            TypeTab[NewTIdx].Fields[
              TypeTab[NewTIdx].FieldCount].Offset :=
                TypeTab[NewTIdx].Size;
            Inc(TypeTab[NewTIdx].FieldCount);
            TypeTab[NewTIdx].Size :=
              TypeTab[NewTIdx].Size + TypeSizeof(BaseTIdx);
            If Opts.DebugMode Then
              WriteLn('  FIELD: ', BaseStr, ' : type=', BaseTIdx,
                      ' ofs=', TypeTab[NewTIdx].Fields[
                        TypeTab[NewTIdx].FieldCount - 1].Offset);
          End
          Else
            WarnMsg('trop de champs dans le record');

          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
            TplNextToken;
        End
        Else
        Begin
          WarnMsg('identificateur attendu dans record');
          TplNextToken;
        End;
      End;

      If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'end') Then
        TplNextToken;

      Idx := SymAdd(TName, SC_TYPE, NewTIdx);
      If Idx >= 0 Then
        SymTab[Idx].MangledName := StrUpperCase(TName);

      If Opts.DebugMode Then
        WriteLn('  TYPE_RECORD: ', TName,
                ' size=', TypeTab[NewTIdx].Size,
                ' fields=', TypeTab[NewTIdx].FieldCount);
    End
    Else
    { --- Enumeration : (val1, val2, ...) --- }
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
    Begin
      TplNextToken;
      If TypeCount >= MAX_TYPE Then
      Begin
        WarnMsg('nombre maximal de types atteint');
        Break;
      End;
      NewTIdx := TypeCount;
      Inc(TypeCount);
      TypeTab[NewTIdx].Kind        := TKP_ENUM;
      TypeTab[NewTIdx].Size        := 4;
      TypeTab[NewTIdx].BaseTypeIdx := TY_IDX_INTEGER;
      TypeTab[NewTIdx].Lo          := 0;
      TypeTab[NewTIdx].Hi          := 0;
      TypeTab[NewTIdx].FieldCount  := 0;
      TypeTab[NewTIdx].EnumCount   := 0;

      Idx := SymAdd(TName, SC_TYPE, NewTIdx);
      If Idx >= 0 Then
        SymTab[Idx].MangledName := PSP_ENUM_PFX + StrUpperCase(TName);

      OrdVal := 0;
      While (CurToken.Kind <> TK_EOF) And
            Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')')) Do
      Begin
        If CurToken.Kind = TK_IDENT Then
        Begin
          EnName := CurToken.Val;
          TplNextToken;

          Idx := SymAdd(EnName, SC_ENUM_VAL, NewTIdx);
          If Idx >= 0 Then
          Begin
            SymTab[Idx].ImmVal      := OrdVal;
            SymTab[Idx].MangledName := PSP_ENUM_PFX +
                                         StrUpperCase(EnName);
          End;

          If TypeTab[NewTIdx].EnumCount < MAX_ENUM Then
          Begin
            TypeTab[NewTIdx].Enums[
              TypeTab[NewTIdx].EnumCount].Name := EnName;
            TypeTab[NewTIdx].Enums[
              TypeTab[NewTIdx].EnumCount].Value := OrdVal;
            Inc(TypeTab[NewTIdx].EnumCount);
          End;

          If Opts.DebugMode Then
            WriteLn('  ENUM: ', TName, '.', EnName, ' = ', OrdVal);

          Inc(OrdVal);
        End
        Else
        Begin
          WarnMsg('identificateur attendu dans enumeration');
          TplNextToken;
        End;

        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
          TplNextToken;
      End;

      If OrdVal > 0 Then
        TypeTab[NewTIdx].Hi := OrdVal - 1;

      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
        TplNextToken;

      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
        TplNextToken;

      Continue;
    End
    Else
    { --- Sous-plage avec litteral entier : lo..hi --- }
    If (CurToken.Kind = TK_INTEGER) Then
    Begin
      LoVal := CurToken.IntVal;
      TplNextToken;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '..') Then
      Begin
        TplNextToken;
        ParseExpr(Ev);
        If TypeCount >= MAX_TYPE Then
        Begin
          WarnMsg('nombre maximal de types atteint');
          Break;
        End;
        NewTIdx := TypeCount;
        Inc(TypeCount);
        TypeTab[NewTIdx].Kind        := TKP_SUBRANGE;
        TypeTab[NewTIdx].Size        := 4;
        TypeTab[NewTIdx].BaseTypeIdx := TY_IDX_INTEGER;
        TypeTab[NewTIdx].Lo          := LoVal;
        TypeTab[NewTIdx].Hi          := Ev.ImmVal;
        TypeTab[NewTIdx].FieldCount  := 0;
        TypeTab[NewTIdx].EnumCount   := 0;

        Idx := SymAdd(TName, SC_TYPE, NewTIdx);
        If Idx >= 0 Then
          SymTab[Idx].MangledName := StrUpperCase(TName);

        If Opts.DebugMode Then
          WriteLn('  TYPE_SUBRANGE: ', TName, ' = ',
                  LoVal, '..', Ev.ImmVal);

        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
          TplNextToken;

        Continue;
      End
      Else
      Begin
        WarnMsg('declaration de type inattendue pour ' + TName);
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
          TplNextToken;
        Continue;
      End;
    End
    Else
    Begin
      { Alias de type ou sous-plage avec ident }
      If (CurToken.Kind = TK_KEYWORD) Or
         (CurToken.Kind = TK_IDENT) Then
      Begin
        BaseStr := CurToken.Val;
        BaseTIdx := TypeResolve(BaseStr);
        If BaseTIdx = TY_UNKNOWN Then
        Begin
          WarnMsg('type inconnu: ' + BaseStr);
          BaseTIdx := TY_IDX_INTEGER;
        End;
        TplNextToken;

        { Verifier si c est un sous-intervalle ident..hi }
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '..') Then
        Begin
          Idx := SymFind(BaseStr);
          If (Idx >= 0) And
             (SymTab[Idx].Cat In [SC_CONST, SC_ENUM_VAL]) Then
            LoVal := SymTab[Idx].ImmVal
          Else
          Begin
            WarnMsg('borne inferieure non constante: ' + BaseStr);
            LoVal := 0;
          End;
          TplNextToken;
          ParseExpr(Ev);
          If TypeCount >= MAX_TYPE Then
          Begin
            WarnMsg('nombre maximal de types atteint');
            Break;
          End;
          NewTIdx := TypeCount;
          Inc(TypeCount);
          TypeTab[NewTIdx].Kind        := TKP_SUBRANGE;
          TypeTab[NewTIdx].Size        := 4;
          TypeTab[NewTIdx].BaseTypeIdx := TY_IDX_INTEGER;
          TypeTab[NewTIdx].Lo          := LoVal;
          TypeTab[NewTIdx].Hi          := Ev.ImmVal;
          TypeTab[NewTIdx].FieldCount  := 0;
          TypeTab[NewTIdx].EnumCount   := 0;

          Idx := SymAdd(TName, SC_TYPE, NewTIdx);
          If Idx >= 0 Then
            SymTab[Idx].MangledName := StrUpperCase(TName);

          If Opts.DebugMode Then
            WriteLn('  TYPE_SUBRANGE: ', TName, ' = ',
                    LoVal, '..', Ev.ImmVal);

          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
            TplNextToken;

          Continue;
        End;

        { Alias de type simple : TYPE T2 = T1 }
        Idx := SymAdd(TName, SC_TYPE, BaseTIdx);
        If Idx >= 0 Then
          SymTab[Idx].MangledName := StrUpperCase(TName);
      End
      Else
      Begin
        WarnMsg('type ou record attendu');
        TplNextToken;
      End;
    End;

    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
      TplNextToken;
  End;
End;
Procedure ParseIncDecStmt(IsInc : Boolean); Begin End;

{ ============================================================
  TODO 17 - ENUMERATIONS ET SOUS-INTERVALLES [IMPLEMENTE]
  ============================================================ }
{ Le parsing des enumerations TYPE T = (Val1, Val2, ...) et
  des sous-intervalles TYPE T = lo..hi est integre dans
  ParseTypeDecl ci-dessus.
  - Enumeration : detecte '(' apres '=', cree type TKP_ENUM,
    ajoute chaque valeur comme SC_ENUM_VAL avec ordinal auto.
  - Sous-intervalle entier : detecte TK_INTEGER suivi de '..',
    cree type TKP_SUBRANGE avec Lo/Hi.
  - Sous-intervalle ident : detecte ident suivi de '..',
    resout constante/enum_val pour Lo.
  Les builtins Succ, Pred, Low, High sont deja dans ParsePrimary.
  Les valeurs d enumeration sont resolues dans ParsePrimary
  via SC_ENUM_VAL -> EK_IMM.                                    }

{ ============================================================
  TODO 16 - ENREGISTREMENTS (RECORD) ET WITH [IMPLEMENTE]
  ============================================================ }
{ ParseWithStmt : WITH RecVar DO stmt
  Empile le symbole du record sur la pile with (WithSymIdx).
  Les champs du record deviennent accessibles sans prefixe.
  Imbrication max : MAX_WITH niveaux.
  En sortie, depile le with-stack.                                }
Procedure ParseWithStmt;
Var
  WSIdx : Integer;
Begin
  TplNextToken;
  If CurToken.Kind = TK_IDENT Then
  Begin
    WSIdx := SymFind(CurToken.Val);
    If (WSIdx >= 0) And
       (SymTab[WSIdx].TypeIdx >= 0) And
       (SymTab[WSIdx].TypeIdx < TypeCount) And
       (TypeTab[SymTab[WSIdx].TypeIdx].Kind = TKP_RECORD) Then
    Begin
      TplNextToken;
      If WithTop < MAX_WITH - 1 Then
      Begin
        Inc(WithTop);
        WithSymIdx[WithTop] := WSIdx;
      End
      Else
        WarnMsg('imbrication with trop profonde');
      If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'do') Then
        TplNextToken;
      ParseStatement;
      If WithTop >= 0 Then
        Dec(WithTop);
    End
    Else
    Begin
      WarnMsg('with : variable record attendue');
      TplNextToken;
      If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'do') Then
        TplNextToken;
      ParseStatement;
    End;
  End
  Else
    WarnMsg('identificateur attendu apres with');
End;

{ --- Stubs Exceptions (TODO 21) --- }
Procedure ParseTryExcept; Begin End;

{ ============================================================
  TODO 01 - INFRASTRUCTURE ET OPTIONS [IMPLEMENTE]
  ============================================================ }

{ ---- FatalError ------------------------------------------ }
Procedure FatalError(Const Msg : TString);
Begin
  WriteLn('PSPCW32: FATAL: ', Msg);
  If OutFOpen Then
  Begin
    Close(OutF);
    OutFOpen := False;
    Assign(OutF, Opts.OutFile);
    Erase(OutF);
  End;
  Halt(EXIT_ERROR);
End;

{ ---- WarnMsg --------------------------------------------- }
Procedure WarnMsg(Const Msg : TString);
Begin
  If Not Opts.Warnings Then Exit;
  WriteLn('PSPCW32: warning: ', Msg);
  Inc(WarnCount);
End;

{ ---- ErrorMsg, Expect, SkipTo -------------------- }

Procedure ErrorMsg(Const Msg : TString);
Begin
  WriteLn('PSPCW32: erreur ligne ', LexLineNo, ' : ', Msg);
  Inc(ErrorCount);
End;

Procedure Expect(Const Expected : TString);
Begin
  If CurToken.Val <> Expected Then
  Begin
    ErrorMsg('''' + Expected + ''' attendu, trouve ''' + CurToken.Val + '''');
    SkipTo;
  End
  Else
    TplNextToken;
End;

Procedure SkipTo;
Begin
  While (CurToken.Kind <> TK_EOF) And
        Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';')) And
        Not ((CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'end')) And
        Not ((CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'begin')) And
        Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '%>')) Do
    TplNextToken;
End;

{ ---- Banniere ---------------------------------------------- }

Procedure ShowBanner;
Begin
  WriteLn('PSPCW32 v', PSPCW32_VERSION, ' (', PSPCW32_DATE, ')');
  WriteLn('Compilateur Pascal Server Pages -> assembleur 80386 / Win32');
  WriteLn('Turbo Pascal / Free Pascal (-Mtp)  Cible: MASM .386 .MODEL FLAT');
  WriteLn;
End;

Procedure ShowUsage;
Begin
  WriteLn('PSPCW32 - Compilateur de PSP (Pascal Server Pages) pour ',
          'l''assembleur du microprocesseur 80386 (Windows 32 bits).');
  WriteLn;
  WriteLn('Syntaxe : PSPCW32 <page.psp> [-o sortie] [-v] [-d] [-w] [-obj] [-asm]');
  WriteLn;
  WriteLn('  page.psp   : fichier Pascal Server Pages source');
  WriteLn('  -o nom     : specifier le nom du fichier de sortie');
  WriteLn('  -v         : mode verbeux (banniere + statistiques)');
  WriteLn('  -d         : debug tokens (affiche chaque token)');
  WriteLn('  -w         : activer les avertissements');
  WriteLn('  -obj       : produire uniquement un .OBJ (format COFF 32 bits)');
  WriteLn('  -asm       : produire egalement un listing assembleur .ASM');
  WriteLn('  -h         : afficher cette aide');
  WriteLn;
  WriteLn('Par defaut, PSPCW32 produit un fichier .EXE (PE Windows 32 bits).');
  WriteLn;
  Halt(EXIT_USAGE);
End;

Procedure ShowHelp;
Begin
  ShowBanner;
  ShowUsage;
End;

{ ---- Utilitaires chaines ------------------------------------ }

Function StrLowerCase(Const S : TString) : TString;
Var
  I : Integer;
  R : TString;
Begin
  R := S;
  For I := 1 To Length(R) Do
    If (R[I] >= 'A') And (R[I] <= 'Z') Then
      R[I] := Chr(Ord(R[I]) + 32);
  StrLowerCase := R;
End;

Function StrUpperCase(Const S : TString) : TString;
Var
  I : Integer;
  R : TString;
Begin
  R := S;
  For I := 1 To Length(R) Do
    If (R[I] >= 'a') And (R[I] <= 'z') Then
      R[I] := Chr(Ord(R[I]) - 32);
  StrUpperCase := R;
End;

Function IntToStr(N : LongInt) : TString;
Var
  S : TString;
Begin
  Str(N, S);
  IntToStr := S;
End;

{ Retourne '[EBP+n]' ou '[EBP-n]' selon le signe }
Function EBPOfs(Ofs : Integer) : TString;
Begin
  If Ofs >= 0 Then
    EBPOfs := '[EBP+' + IntToStr(Ofs) + ']'
  Else
    EBPOfs := '[EBP' + IntToStr(Ofs) + ']';
End;

Function StrToIntDef(Const S : TString; Def : LongInt) : LongInt;
Var
  V : LongInt;
  C : Integer;
Begin
  Val(S, V, C);
  If C = 0 Then StrToIntDef := V
  Else          StrToIntDef := Def;
End;

{ Extrait le nom de base d un chemin (sans extension) }
Function BaseName(Const Path : TString) : TString;
Var
  I, LastSep, LastDot : Integer;
  S : TString;
Begin
  LastSep := 0;
  LastDot := 0;
  For I := 1 To Length(Path) Do
  Begin
    If (Path[I] = '\') Or (Path[I] = '/') Or (Path[I] = ':') Then
      LastSep := I;
    If Path[I] = '.' Then
      LastDot := I;
  End;
  If LastDot > LastSep Then
    S := Copy(Path, LastSep + 1, LastDot - LastSep - 1)
  Else
    S := Copy(Path, LastSep + 1, Length(Path));
  BaseName := S;
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

{ Retourne l extension d un chemin (avec le point) }
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
    ExtractExt := StrLowerCase(Copy(Path, LastDot, Length(Path) - LastDot + 1))
  Else
    ExtractExt := '';
End;

{ ---- Initialisation des options ----------------------------- }

Procedure InitOptions;
Begin
  Opts.SrcFile   := '';
  Opts.OutFile   := '';
  Opts.Verbose   := False;
  Opts.DebugMode := False;
  Opts.Warnings  := False;
  Opts.EmitExe   := True;    { par defaut : produire un .EXE }
  Opts.EmitObj   := False;
  Opts.EmitAsm   := False;
End;

{ ---- Analyse des arguments de la ligne de commande --------- }

Procedure ParseArgs;
Var
  I   : Integer;
  Arg : TString;
  Ext : TString;
Begin
  InitOptions;
  If ParamCount = 0 Then
    ShowUsage;

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
    Else If Arg = '-obj' Then
    Begin
      Opts.EmitObj := True;
      Opts.EmitExe := False;
    End
    Else If Arg = '-asm' Then
      Opts.EmitAsm := True
    Else If Arg = '-o' Then
    Begin
      If I < ParamCount Then
      Begin
        Inc(I);
        Opts.OutFile := ParamStr(I);
      End
      Else
      Begin
        WriteLn('PSPCW32: -o requiert un nom de fichier');
        ShowUsage;
      End;
    End
    Else If Arg[1] = '-' Then
    Begin
      WriteLn('PSPCW32: option inconnue: ', Arg);
      ShowUsage;
    End
    Else If Opts.SrcFile = '' Then
      Opts.SrcFile := Arg
    Else
    Begin
      WriteLn('PSPCW32: argument inattendu: ', Arg);
      ShowUsage;
    End;

    Inc(I);
  End;

  If Opts.SrcFile = '' Then
  Begin
    WriteLn('PSPCW32: fichier source manquant');
    ShowUsage;
  End;

  { Verifier l extension .psp }
  Ext := ExtractExt(Opts.SrcFile);
  If (Ext <> '.psp') Then
    WarnMsg('extension attendue .psp, trouvee: ' + Ext);

  { Fichier de sortie par defaut selon le mode }
  If Opts.OutFile = '' Then
  Begin
    If Opts.EmitObj Then
      Opts.OutFile := ReplaceExt(Opts.SrcFile, '.obj')
    Else
      Opts.OutFile := ReplaceExt(Opts.SrcFile, '.exe');
  End;
End;

{ ---- Nettoyage -------------------------------------------- }

Procedure Cleanup;
Begin
  If LexOpened Then
  Begin
    Close(LexSrcF);
    LexOpened := False;
  End;
  If OutFOpen Then
  Begin
    Close(OutF);
    OutFOpen := False;
  End;
End;

{ ---- Initialisation generale -------------------------------- }

Procedure GlobalInit;
Begin
  ErrorCount := 0;
  WarnCount  := 0;
  TotalLines := 0;
  TotalSyms  := 0;
  OutFOpen   := False;
  LexOpened  := False;
  LexEOF     := False;
  LexLineNo  := 0;
  LexColNo   := 1;
  LexLine    := '';
  CurToken.Kind    := TK_EOF;
  CurToken.Val     := '';
  CurToken.IntVal  := 0;
  CurToken.RealVal := 0.0;
  CurToken.Line    := 0;
  CurToken.Col     := 0;
  DataCount   := 0;
  LabelGenSeq := 0;
  SymCount      := 0;
  CurScopeLevel := 0;
  CurScopeId    := 0;
  ScopeIdSeq    := 0;
  TypeCount := 0;
  CurFrameOffset    := 0;
  HasPendingAssign  := False;
  PendingAssignName := '';
  LoopTop := -1;
  CurFuncName   := '';
  CurFuncRetOfs := 0;
  CurRetLabel   := '';
  CurNestLevel  := 0;
  CurParamBytes := 0;
  MainBodyEmitted := False;
  RuntimeEmitted  := False;
  WithTop := -1;
  IncTop        := -1;
  DefineCount   := 0;
  CompilerMode  := 'TP';
  ContentTypeLbl := '';
  LexSrcFName   := '';
  TypeInit;
  SymInit;
End;

{ ============================================================
  TODO 19 - TEMPLATE PSP [IMPLEMENTE]
  ============================================================ }
{ Boucle principale du compilateur PSP : alternance HTML / code
  Pascal via les balises <% %>, <%= %>, <%@ %>.
  - TK_HTML         : fragment HTML statique -> EmitHtmlFragment
  - TK_PSP_OPEN     : balise <% -> passer en mode code
  - TK_PSP_EXPR_OPEN: balise <%= -> evaluer et imprimer expression
  - TK_PSP_CLOSE    : balise %> -> retour mode HTML
  - TK_PSP_DIRECTIVE: balise <%@ -> parser directive de page
  - TK_KEYWORD/IDENT: instruction Pascal -> ParseStatement }

Procedure Run;
Begin
  GlobalInit;
  If Opts.Verbose Then ShowBanner;

  { Verifier que le fichier source existe }
  Assign(LexSrcF, Opts.SrcFile);
  Reset(LexSrcF);
  If IOResult <> 0 Then
    FatalError('impossible d''ouvrir le fichier source: ' + Opts.SrcFile);
  LexOpened := True;
  LexSrcFName := Opts.SrcFile;

  { Creer le fichier de sortie }
  Assign(OutF, Opts.OutFile);
  Rewrite(OutF);
  If IOResult <> 0 Then
    FatalError('impossible de creer le fichier de sortie: ' + Opts.OutFile);
  OutFOpen := True;

  { Initialiser le lexeur et l analyseur template }
  LexInit;
  TplInit;
  { Emettre l en-tete ASM }
  EmitHeader;

  { Boucle principale : analyseur de template PSP }
  TplNextToken;  { Lire le premier token }
  If Opts.DebugMode Then
  Begin
    { Debug : scanner et afficher tous les tokens }
    While CurToken.Kind <> TK_EOF Do
      TplNextToken;
  End
  Else
  Begin
    While CurToken.Kind <> TK_EOF Do
    Begin
      { --- Fragments HTML (hors <% %>) --- }
      If CurToken.Kind = TK_HTML Then
      Begin
        EmitHtmlFragment(CurToken.Val);
        TplNextToken;
      End
      { --- Balise ouvrante <% : passer en mode code --- }
      Else If CurToken.Kind = TK_PSP_OPEN Then
      Begin
        TplNextToken;  { consommer <%, prochain token = code Pascal }
      End
      { --- Expression inline <%= expr %> --- }
      Else If CurToken.Kind = TK_PSP_EXPR_OPEN Then
      Begin
        TplNextToken;  { consommer <%=, prochain token = debut expr }
        EmitExprInline;
      End
      { --- Balise fermante %> : retour HTML --- }
      Else If CurToken.Kind = TK_PSP_CLOSE Then
      Begin
        TplNextToken;  { consommer %>, retour en mode HTML }
      End
      { --- Directive <%@ ... %> : parser attributs --- }
      Else If CurToken.Kind = TK_PSP_DIRECTIVE Then
      Begin
        ParsePSPDirective;
      End
      { --- Instructions Pascal (delegation a ParseStatement) --- }
      Else If (CurToken.Kind = TK_KEYWORD) Or
              (CurToken.Kind = TK_IDENT) Then
      Begin
        ParseStatement;
        { Consommer les ; residuels }
        While (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Do
          TplNextToken;
      End
      Else
        TplNextToken;  { Avancer seulement si aucun match }
    End;
  End;

  { Emettre le pied de page ASM }
  EmitFooter;
  { Fermer l analyseur template }
  TplClose;
  { Emettre le segment de donnees }
  EmitDataSeg;
  { Directive END }
  If OutFOpen Then
    EmitRaw('        END     ' + PSP_FN_PFX + 'main');


  Cleanup;
  If Opts.Verbose Then Begin
    WriteLn('Compilation terminee : ', Opts.SrcFile, ' -> ', Opts.OutFile);
    WriteLn('  Lignes         : ', TotalLines);
    WriteLn('  Symboles       : ', TotalSyms);
    WriteLn('  Erreurs        : ', ErrorCount);
    WriteLn('  Avertissements : ', WarnCount);
    If Opts.EmitExe Then
      WriteLn('  Mode           : EXE (PE Win32)')
    Else If Opts.EmitObj Then
      WriteLn('  Mode           : OBJ (COFF 32 bits)');
    If Opts.EmitAsm Then
      WriteLn('  Listing ASM    : oui');
  End;
  If ErrorCount > 0 Then Halt(EXIT_ERROR)
                    Else Halt(EXIT_OK);
End;

{ ============================================================
  PROGRAMME PRINCIPAL
  ============================================================ }

BEGIN
 If(ParamStr(1)='/?')or(ParamStr(1)='--help')or(ParamStr(1)='-h')or
   (ParamStr(1)='/h')or(ParamStr(1)='/H')Then Begin
  ShowHelp;
  Halt(0);
 End;
 ParseArgs;
 Run;
END.
